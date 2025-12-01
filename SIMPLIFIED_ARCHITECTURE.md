# Simplified Authentication Architecture

## Overview

This implementation uses a **single app registration** in Azure Entra ID for authentication between APIM and the AKS microservice. Clients authenticate to APIM using **subscription keys**.

## Authentication Flow

```
┌─────────┐                    ┌──────┐                    ┌─────────────┐
│ Client  │ ─subscription─key─→│ APIM │ ─OAuth─2.0─token──→│ AKS Service │
└─────────┘                    └──────┘                    └─────────────┘
                                   │                              │
                                   │                              │
                                   └──────────┬───────────────────┘
                                              │
                                              ▼
                                    ┌──────────────────┐
                                    │  Azure Entra ID  │
                                    │                  │
                                    │  Single App Reg  │
                                    │  (API App)       │
                                    └──────────────────┘
```

## Components

### 1. Client → APIM
- **Authentication**: APIM Subscription Key
- **Header**: `Ocp-Apim-Subscription-Key: YOUR_KEY`
- **Purpose**: Identify and authorize the client application

### 2. APIM → AKS Microservice
- **Authentication**: OAuth 2.0 JWT Token
- **Method**: APIM uses its managed identity to acquire token
- **Header**: `Authorization: Bearer <token>`
- **Purpose**: Secure backend authentication

### 3. Single App Registration
- **Name**: `aks-hello-world-api`
- **Used By**:
  - APIM managed identity (to acquire tokens)
  - AKS microservice (to validate tokens)
- **App Role**: `API.Access` (assigned to APIM managed identity)

## Why This Works

### APIM Side
1. APIM has a **system-assigned managed identity**
2. This managed identity is granted the `API.Access` app role
3. APIM uses `authentication-managed-identity` policy to request token:
   ```xml
   <authentication-managed-identity 
       resource="api://[API_APP_ID]" 
       output-token-variable-name="msi-access-token" />
   ```
4. Azure Entra ID issues a token with:
   - `aud` (audience): `api://[API_APP_ID]`
   - `appid`: APIM's managed identity client ID
   - `roles`: `["API.Access"]`

### AKS Microservice Side
1. Pod uses **workload identity** (federated credential)
2. Service account is linked to the same app registration
3. Microservice validates incoming tokens using `Microsoft.Identity.Web`
4. Validation checks:
   - Token audience matches `api://[API_APP_ID]`
   - Token is signed by Azure Entra ID
   - Token is not expired
   - Token has required claims

## Benefits of Single App Registration

✅ **Simpler Setup**
- Only one app registration to manage
- Fewer manual steps in Azure Portal
- Less configuration to maintain

✅ **Clear Separation of Concerns**
- Client authentication: APIM subscription keys
- Backend authentication: OAuth 2.0 tokens
- No confusion about which app ID to use

✅ **Production Ready**
- Still follows OAuth 2.0 best practices
- Managed identities (no secrets in code)
- Workload identity (no secrets in pods)
- Token-based authentication

✅ **Easier Troubleshooting**
- Single app registration to check
- Clearer token flow
- Simpler permission model

## Configuration Variables

### Before (2 App Registrations)
```bash
export TENANT_ID="..."
export MICROSERVICE_APP_ID="..."  # API app
export APIM_APP_ID="..."          # Client app
```

### After (1 App Registration)
```bash
export TENANT_ID="..."
export API_APP_ID="..."           # Used by both APIM and microservice
```

## Token Claims

When APIM acquires a token, it contains:

```json
{
  "aud": "api://[API_APP_ID]",
  "iss": "https://sts.windows.net/[TENANT_ID]/",
  "appid": "[APIM_MANAGED_IDENTITY_CLIENT_ID]",
  "roles": ["API.Access"],
  "tid": "[TENANT_ID]",
  "uti": "...",
  "ver": "1.0"
}
```

The microservice validates:
- ✅ `aud` matches its configured audience
- ✅ Token is from trusted issuer (Azure Entra ID)
- ✅ Token signature is valid
- ✅ Token is not expired

## Security Considerations

### Client Layer (APIM Subscription Keys)
- Rate limiting per subscription
- Revocable keys
- Usage tracking and analytics
- Different keys for different clients/environments

### Backend Layer (OAuth 2.0 Tokens)
- Short-lived tokens (typically 1 hour)
- Cryptographically signed
- Cannot be forged
- Validated on every request
- No credentials stored in code or configuration

## Comparison with 2-App-Registration Approach

| Aspect | Single App (This Implementation) | Two Apps (Traditional) |
|--------|----------------------------------|------------------------|
| Setup Complexity | ⭐⭐ Simple | ⭐⭐⭐⭐ Complex |
| Manual Steps | 2 | 3-4 |
| App Registrations | 1 | 2 |
| Token Validation | Same app ID | Different app IDs |
| Security | ✅ Secure | ✅ Secure |
| OAuth 2.0 Compliance | ✅ Yes | ✅ Yes |
| Production Ready | ✅ Yes | ✅ Yes |
| Use Case | APIM → Backend | Client → Backend |

## When to Use Each Approach

### Use Single App Registration (This Implementation)
- ✅ APIM is the only client
- ✅ Client authentication handled by APIM (subscription keys)
- ✅ Want simpler setup and maintenance
- ✅ Backend-to-backend authentication

### Use Two App Registrations
- Multiple different clients need tokens
- Clients authenticate directly with Entra ID
- Need fine-grained permission delegation
- Client-to-backend authentication (e.g., SPA, mobile app)

## Summary

This implementation provides a **production-ready, secure authentication pattern** that:
- Uses APIM subscription keys for client authentication
- Uses OAuth 2.0 tokens for backend authentication
- Leverages managed identities (no secrets)
- Implements workload identity (no credentials in pods)
- Simplifies setup with a single app registration

The approach is **fully compliant with OAuth 2.0** and follows **Microsoft's recommended patterns** for service-to-service authentication in Azure.
