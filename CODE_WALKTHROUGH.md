# Line-by-Line Code Walkthrough: Authentication Flow

This document provides an exhaustive, line-by-line explanation of how authentication works in the Hello World microservice, from application startup to processing an authenticated request.

## Table of Contents
1. [Application Startup](#application-startup)
2. [APIM Token Acquisition](#apim-token-acquisition)
3. [Request Processing](#request-processing)
4. [Token Validation Deep Dive](#token-validation-deep-dive)
5. [Controller Execution](#controller-execution)

---

## Application Startup

### Phase 1: Configuration Loading (appsettings.json)

When the application starts, it loads configuration from `appsettings.json`:

```json
{
  "AzureAd": {
    "Instance": "https://login.microsoftonline.com/",
    "TenantId": "8b00db25-a991-48c8-b92d-384c8be1fa14",
    "ClientId": "ded658c3-3903-4f40-bf82-893c1f0e824f",
    "Audience": "api://ded658c3-3903-4f40-bf82-893c1f0e824f"
  }
}
```

**What each field means:**
- **Instance**: The base URL for Azure Entra ID authentication endpoints
- **TenantId**: Your Azure AD tenant identifier (unique to your organization)
- **ClientId**: The Application ID of this microservice in Entra ID
- **Audience**: The expected `aud` claim in incoming JWT tokens (must match ClientId)

### Phase 2: Service Registration (Program.cs Lines 1-25)

```csharp
// Line 1-2: Import required namespaces
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;
```
- `JwtBearerDefaults`: Provides constants like the authentication scheme name
- `Microsoft.Identity.Web`: Microsoft's library that simplifies Azure AD integration

```csharp
// Line 4: Create the application builder
var builder = WebApplication.CreateBuilder(args);
```
- Creates a `WebApplicationBuilder` instance
- Loads configuration from appsettings.json, environment variables, command-line args
- Sets up dependency injection container

```csharp
// Lines 7-9: Register MVC services
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();
```
- `AddControllers()`: Registers services needed for API controllers
- `AddEndpointsApiExplorer()`: Enables endpoint metadata for Swagger
- `AddSwaggerGen()`: Configures Swagger/OpenAPI documentation

```csharp
// Lines 12-13: Configure Authentication ⭐ CRITICAL
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));
```

**Line 12 breakdown:**
- `AddAuthentication(...)`: Registers authentication services in DI container
- `JwtBearerDefaults.AuthenticationScheme`: Sets "Bearer" as the default authentication scheme

**Line 13 breakdown:**
- `AddMicrosoftIdentityWebApi(...)`: Extension method from Microsoft.Identity.Web
- Reads the "AzureAd" section from configuration
- **Under the hood, this method:**
  1. Configures `JwtBearerOptions` with Azure AD-specific settings
  2. Sets up automatic OIDC metadata discovery
  3. Configures token validation parameters:
     ```csharp
     ValidateIssuer = true,
     ValidIssuer = "https://sts.windows.net/{TenantId}/",
     ValidateAudience = true,
     ValidAudience = "api://{ClientId}",
     ValidateLifetime = true,
     ValidateIssuerSigningKey = true
     ```
  4. Registers a background service that fetches public keys from:
     `https://login.microsoftonline.com/{TenantId}/v2.0/.well-known/openid-configuration`

```csharp
// Line 16: Add Authorization services
builder.Services.AddAuthorization();
```
- Registers authorization services (policy evaluation, role checks)
- Required for `[Authorize]` attribute to work

### Phase 3: Middleware Pipeline (Program.cs Lines 26-63)

```csharp
// Line 26: Build the application
var app = builder.Build();
```
- Constructs the `WebApplication` from the builder
- Finalizes service registration
- Creates the HTTP request pipeline

```csharp
// Lines 36-54: Custom logging middleware
app.Use(async (context, next) =>
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
    logger.LogInformation("Incoming request: {Method} {Path}", 
        context.Request.Method, context.Request.Path);
    
    if (context.Request.Headers.ContainsKey("Authorization"))
    {
        var authHeader = context.Request.Headers["Authorization"].ToString();
        logger.LogInformation("Authorization header present: {Header}", 
            authHeader.Length > 20 ? authHeader.Substring(0, 20) + "..." : "Bearer token");
    }
    else
    {
        logger.LogWarning("No Authorization header found");
    }
    
    await next();
});
```
- This middleware runs **before** authentication
- Logs every incoming request
- Checks for Authorization header (but doesn't validate it yet)
- `await next()`: Passes control to the next middleware

```csharp
// Line 56: Authentication Middleware ⭐ CRITICAL
app.UseAuthentication();
```
**This is where token validation happens!** When a request arrives:
1. Middleware checks for `Authorization: Bearer <token>` header
2. If found, extracts the token
3. Validates the token (see "Token Validation Deep Dive" below)
4. If valid, populates `HttpContext.User` with claims from the token
5. If invalid, sets `HttpContext.User` to an unauthenticated principal

```csharp
// Line 57: Authorization Middleware
app.UseAuthorization();
```
- Checks if the authenticated user meets authorization requirements
- Evaluates `[Authorize]` attributes on controllers/actions
- If user is not authenticated and endpoint requires auth → returns 401
- If user lacks required role/policy → returns 403

```csharp
// Lines 60-63: Endpoint mapping
app.MapHealthChecks("/health");
app.MapControllers();
```
- `MapHealthChecks`: Registers `/health` endpoint (no auth required)
- `MapControllers`: Scans for controllers and registers their routes

---

## APIM Token Acquisition

Before APIM can call our microservice, it must obtain an access token.

### Step 1: APIM Policy Execution

In APIM, the following policy is configured:

```xml
<authentication-managed-identity 
    resource="api://ded658c3-3903-4f40-bf82-893c1f0e824f" 
    output-token-variable-name="msi-access-token" />
```

**What happens:**
1. APIM's policy engine executes this directive
2. It calls the Azure Instance Metadata Service (IMDS) endpoint

### Step 2: IMDS Token Request

APIM makes an HTTP request to:
```
GET http://169.254.169.254/metadata/identity/oauth2/token
    ?api-version=2018-02-01
    &resource=api://ded658c3-3903-4f40-bf82-893c1f0e824f
```

**Headers:**
```
Metadata: true
```

**What this means:**
- `169.254.169.254`: Special link-local IP address for Azure VM metadata service
- `resource`: The App ID URI of our microservice
- IMDS knows the identity of the caller (APIM's managed identity) from the VM context

### Step 3: Entra ID Token Issuance

IMDS forwards the request to Azure Entra ID:

1. **Identity Verification**: Entra ID verifies the managed identity's credentials
2. **Permission Check**: Entra ID checks if the APIM managed identity has been granted the `API.Access` role on the microservice app registration
3. **Token Generation**: If authorized, Entra ID creates a JWT with:
   ```json
   {
     "aud": "api://ded658c3-3903-4f40-bf82-893c1f0e824f",
     "iss": "https://sts.windows.net/8b00db25-a991-48c8-b92d-384c8be1fa14/",
     "iat": 1732766400,
     "nbf": 1732766400,
     "exp": 1732770000,
     "appid": "<APIM_MANAGED_IDENTITY_CLIENT_ID>",
     "roles": ["API.Access"],
     "tid": "8b00db25-a991-48c8-b92d-384c8be1fa14"
   }
   ```
4. **Signing**: The token is signed with Entra ID's private key (RS256 algorithm)

### Step 4: APIM Forwards Request

APIM receives the token and injects it:

```http
GET /api/hello HTTP/1.1
Host: hello-world-service.hello-world.svc.cluster.local
Authorization: Bearer eyJ0eXAiOiJKV1QiLCJhbGciOiJSUzI1NiIsIng1dCI6...
```

---

## Request Processing

Now let's trace what happens when this request hits our microservice pod.

### Step 1: Request Arrives at Pod

The request enters the ASP.NET Core pipeline at the Kestrel web server level.

### Step 2: Custom Logging Middleware (Program.cs Line 36)

```csharp
app.Use(async (context, next) =>
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
```
- `context`: The `HttpContext` for this request
- `GetRequiredService<ILogger<Program>>()`: Retrieves logger from DI container

```csharp
    logger.LogInformation("Incoming request: {Method} {Path}", 
        context.Request.Method, context.Request.Path);
```
- Logs: `"Incoming request: GET /api/hello"`

```csharp
    if (context.Request.Headers.ContainsKey("Authorization"))
    {
        var authHeader = context.Request.Headers["Authorization"].ToString();
        logger.LogInformation("Authorization header present: {Header}", 
            authHeader.Length > 20 ? authHeader.Substring(0, 20) + "..." : "Bearer token");
    }
```
- Checks for Authorization header
- Logs first 20 characters: `"Authorization header present: Bearer eyJ0eXAiOiJKV1Qi..."`

```csharp
    await next();
});
```
- Passes control to next middleware (Authentication)

### Step 3: Authentication Middleware (Program.cs Line 56)

```csharp
app.UseAuthentication();
```

This triggers the `JwtBearerHandler` from Microsoft.AspNetCore.Authentication.JwtBearer.

**Internal flow:**

1. **Extract Token**:
   ```csharp
   var authHeader = context.Request.Headers["Authorization"];
   if (authHeader.StartsWith("Bearer "))
   {
       var token = authHeader.Substring(7); // Remove "Bearer " prefix
   }
   ```

2. **Parse Token Header**:
   ```csharp
   // Token structure: [header].[payload].[signature]
   var parts = token.Split('.');
   var header = Base64UrlDecode(parts[0]);
   // header = {"typ":"JWT","alg":"RS256","kid":"..."}
   ```

3. **Fetch Signing Keys** (if not cached):
   ```csharp
   var metadataUrl = "https://login.microsoftonline.com/8b00db25-a991-48c8-b92d-384c8be1fa14/v2.0/.well-known/openid-configuration";
   var metadata = await HttpClient.GetAsync(metadataUrl);
   var jwksUri = metadata.jwks_uri; // "https://login.microsoftonline.com/8b00db25-a991-48c8-b92d-384c8be1fa14/discovery/v2.0/keys"
   var keys = await HttpClient.GetAsync(jwksUri);
   ```

4. **Validate Signature**:
   ```csharp
   var kid = header.kid; // Key ID from token header
   var publicKey = keys.Find(k => k.kid == kid);
   var isSignatureValid = RSA.VerifyData(parts[0] + "." + parts[1], parts[2], publicKey);
   ```

5. **Validate Claims**:
   ```csharp
   var payload = Base64UrlDecode(parts[1]);
   
   // Check Audience
   if (payload.aud != "api://ded658c3-3903-4f40-bf82-893c1f0e824f")
       throw new SecurityTokenInvalidAudienceException();
   
   // Check Issuer
   if (payload.iss != "https://sts.windows.net/8b00db25-a991-48c8-b92d-384c8be1fa14/")
       throw new SecurityTokenInvalidIssuerException();
   
   // Check Expiration
   var now = DateTimeOffset.UtcNow.ToUnixTimeSeconds();
   if (now > payload.exp)
       throw new SecurityTokenExpiredException();
   
   // Check Not Before
   if (now < payload.nbf)
       throw new SecurityTokenNotYetValidException();
   ```

6. **Create ClaimsPrincipal**:
   ```csharp
   var claims = new List<Claim>();
   foreach (var claim in payload)
   {
       claims.Add(new Claim(claim.Key, claim.Value.ToString()));
   }
   
   var identity = new ClaimsIdentity(claims, "Bearer");
   var principal = new ClaimsPrincipal(identity);
   context.User = principal;
   ```

### Step 4: Authorization Middleware (Program.cs Line 57)

```csharp
app.UseAuthorization();
```

At this point, `context.User` is populated. The middleware:
1. Checks if the endpoint has `[Authorize]` attribute
2. Checks if `context.User.Identity.IsAuthenticated` is true
3. If authenticated, allows request to proceed
4. If not authenticated, returns 401 Unauthorized

### Step 5: Controller Routing

The request is routed to `HelloController.Get()` based on:
- Route: `/api/hello`
- HTTP Method: GET
- Controller attribute: `[Route("api/[controller]")]` → `/api/hello`

---

## Controller Execution

### HelloController.cs Line-by-Line

```csharp
// Line 23: Authorize attribute
[Authorize]
```
- Requires authentication for this endpoint
- If `UseAuthorization()` middleware determined user is not authenticated, request never reaches here

```csharp
// Line 24: Method signature
public IActionResult Get()
```
- `IActionResult`: Return type allowing various HTTP responses (200, 401, 404, etc.)
- `User` property is automatically populated by framework from `HttpContext.User`

```csharp
// Line 26: Log the call
_logger.LogInformation("Hello endpoint called by authenticated user");
```

```csharp
// Lines 29-33: Extract all claims
var claims = User.Claims.Select(c => new
{
    type = c.Type,
    value = c.Value
}).ToList();
```
- `User.Claims`: Collection of all claims from the JWT token
- Transforms into anonymous objects for JSON serialization

```csharp
// Lines 45-47: Extract App ID
var appId = User.FindFirst("appid")?.Value 
            ?? User.FindFirst("azp")?.Value 
            ?? "Unknown";
```
- `FindFirst("appid")`: Searches claims for one with type "appid"
- `?.Value`: Null-conditional operator (returns null if claim not found)
- `?? "Unknown"`: Null-coalescing operator (default value)
- **Result**: The Client ID of APIM's managed identity

```csharp
// Lines 51-53: Extract roles
var roles = User.FindAll(ClaimTypes.Role)
    .Select(c => c.Value)
    .ToList();
```
- `FindAll(ClaimTypes.Role)`: Gets all claims with type `http://schemas.microsoft.com/ws/2008/06/identity/claims/role`
- **Result**: `["API.Access"]`

```csharp
// Lines 62-86: Build response object
var response = new
{
    message = "Hello from AKS with Workload Identity!",
    authenticated = true,
    timestamp = DateTime.UtcNow,
    user = new { ... },
    authorization = new { roles = roles, scopes = scopes },
    claims = claims,
    environment = new { ... }
};
```

```csharp
// Line 88: Return HTTP 200 OK
return Ok(response);
```
- Serializes `response` object to JSON
- Sets `Content-Type: application/json`
- Returns HTTP 200 status code

---

## Token Validation Deep Dive

### How Signature Validation Works

1. **Token Structure**:
   ```
   eyJ0eXAiOiJKV1Qi...  .  eyJhdWQiOiJhcGki...  .  kR3xM2...
   [Header (Base64)]      [Payload (Base64)]      [Signature (Base64)]
   ```

2. **Signature Verification**:
   ```csharp
   // What was signed
   var dataToVerify = header_base64 + "." + payload_base64;
   
   // The signature
   var signature = Base64UrlDecode(signature_base64);
   
   // Entra ID's public key (fetched from JWKS endpoint)
   var publicKey = GetPublicKeyFromJWKS(header.kid);
   
   // Verify
   var isValid = publicKey.VerifyData(
       data: Encoding.UTF8.GetBytes(dataToVerify),
       signature: signature,
       hashAlgorithm: HashAlgorithmName.SHA256,
       padding: RSASignaturePadding.Pkcs1
   );
   ```

3. **Why This Works**:
   - Entra ID signs the token with its **private key** (only Entra ID has this)
   - Our microservice verifies with the **public key** (anyone can have this)
   - If signature is valid, token was definitely created by Entra ID and hasn't been modified

### Workload Identity (For Outbound Calls)

**Note**: Our microservice currently only validates *inbound* tokens. It doesn't make outbound calls. But if it did (e.g., to Azure Key Vault), here's how Workload Identity would work:

1. **Service Account Token Projection**:
   - Kubernetes projects a token to: `/var/run/secrets/azure/tokens/azure-identity-token`
   - This token is signed by the AKS OIDC issuer
   - It contains the Service Account identity: `system:serviceaccount:hello-world:hello-world-sa`

2. **Token Exchange**:
   ```csharp
   // Azure.Identity SDK does this automatically
   var k8sToken = File.ReadAllText("/var/run/secrets/azure/tokens/azure-identity-token");
   
   var request = new HttpRequestMessage(HttpMethod.Post, 
       "https://login.microsoftonline.com/{tenantId}/oauth2/v2.0/token");
   request.Content = new FormUrlEncodedContent(new[]
   {
       new KeyValuePair<string, string>("client_id", "ded658c3-3903-4f40-bf82-893c1f0e824f"),
       new KeyValuePair<string, string>("client_assertion_type", "urn:ietf:params:oauth:client-assertion-type:jwt-bearer"),
       new KeyValuePair<string, string>("client_assertion", k8sToken),
       new KeyValuePair<string, string>("scope", "https://vault.azure.net/.default"),
       new KeyValuePair<string, string>("grant_type", "client_credentials")
   });
   
   var response = await httpClient.SendAsync(request);
   var azureToken = await response.Content.ReadAsStringAsync();
   ```

3. **Entra ID Validation**:
   - Entra ID receives the Kubernetes token
   - It validates the token against the AKS OIDC issuer's public keys
   - It checks the federated credential: "Does this Service Account have permission to act as this App Registration?"
   - If yes, it issues an Azure AD access token

---

## Summary

This walkthrough covered:

1. **Startup**: How `AddMicrosoftIdentityWebApi` configures JWT validation
2. **APIM**: How managed identity acquires tokens via IMDS
3. **Request Flow**: How middleware processes requests in order
4. **Token Validation**: Cryptographic signature verification and claim validation
5. **Controller**: How claims are extracted and used in business logic
6. **Workload Identity**: How pods can authenticate to Azure services (for outbound calls)

Every line of code has a specific purpose in the authentication chain, from configuration loading to token validation to claim extraction.
