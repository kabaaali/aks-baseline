using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace HelloWorldService.Controllers;

[ApiController]
[Route("api/[controller]")]
public class HelloController : ControllerBase
{
    private readonly ILogger<HelloController> _logger;

    public HelloController(ILogger<HelloController> logger)
    {
        _logger = logger;
    }

    /// <summary>
    /// Authenticated endpoint that returns hello message with user claims
    /// </summary>
    /// <returns>Hello message with authentication details</returns>
    [HttpGet]
    [Authorize]
    public IActionResult Get()
    {
        _logger.LogInformation("Hello endpoint called by authenticated user");

        // Extract claims from the authenticated user
        var claims = User.Claims.Select(c => new
        {
            type = c.Type,
            value = c.Value
        }).ToList();

        // Get specific claims
        var userId = User.FindFirst(ClaimTypes.NameIdentifier)?.Value 
                     ?? User.FindFirst("oid")?.Value 
                     ?? "Unknown";
        
        var userName = User.FindFirst(ClaimTypes.Name)?.Value 
                       ?? User.FindFirst("name")?.Value 
                       ?? User.FindFirst("preferred_username")?.Value 
                       ?? "Unknown";
        
        var appId = User.FindFirst("appid")?.Value 
                    ?? User.FindFirst("azp")?.Value 
                    ?? "Unknown";
        
        var tenantId = User.FindFirst("tid")?.Value ?? "Unknown";
        
        var roles = User.FindAll(ClaimTypes.Role)
            .Select(c => c.Value)
            .ToList();

        var scopes = User.FindFirst("scp")?.Value?.Split(' ') 
                     ?? User.FindFirst("http://schemas.microsoft.com/identity/claims/scope")?.Value?.Split(' ') 
                     ?? Array.Empty<string>();

        _logger.LogInformation("User authenticated - ID: {UserId}, Name: {UserName}, AppId: {AppId}", 
            userId, userName, appId);

        var response = new
        {
            message = "Hello from AKS with Workload Identity!",
            authenticated = true,
            timestamp = DateTime.UtcNow,
            user = new
            {
                id = userId,
                name = userName,
                applicationId = appId,
                tenantId = tenantId
            },
            authorization = new
            {
                roles = roles,
                scopes = scopes
            },
            claims = claims,
            environment = new
            {
                machineName = Environment.MachineName,
                osVersion = Environment.OSVersion.ToString(),
                dotnetVersion = Environment.Version.ToString()
            }
        };

        return Ok(response);
    }

    /// <summary>
    /// Public endpoint for testing (no authentication required)
    /// </summary>
    /// <returns>Simple hello message</returns>
    [HttpGet("public")]
    [AllowAnonymous]
    public IActionResult GetPublic()
    {
        _logger.LogInformation("Public hello endpoint called");

        return Ok(new
        {
            message = "Hello from AKS! (Public endpoint)",
            authenticated = false,
            timestamp = DateTime.UtcNow
        });
    }

    /// <summary>
    /// Returns information about the current authentication context
    /// </summary>
    /// <returns>Authentication context details</returns>
    [HttpGet("auth-info")]
    [Authorize]
    public IActionResult GetAuthInfo()
    {
        _logger.LogInformation("Auth info endpoint called");

        var authHeader = Request.Headers["Authorization"].ToString();
        var hasToken = !string.IsNullOrEmpty(authHeader);

        return Ok(new
        {
            isAuthenticated = User.Identity?.IsAuthenticated ?? false,
            authenticationType = User.Identity?.AuthenticationType ?? "None",
            hasAuthorizationHeader = hasToken,
            claimsCount = User.Claims.Count(),
            identityName = User.Identity?.Name ?? "Anonymous"
        });
    }
}
