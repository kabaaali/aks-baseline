using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.Identity.Web;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container
builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer();
builder.Services.AddSwaggerGen();

// Configure Azure Entra ID authentication
builder.Services.AddAuthentication(JwtBearerDefaults.AuthenticationScheme)
    .AddMicrosoftIdentityWebApi(builder.Configuration.GetSection("AzureAd"));

// Add authorization
builder.Services.AddAuthorization();

// Configure logging
builder.Logging.ClearProviders();
builder.Logging.AddConsole();
builder.Logging.AddDebug();

// Add health checks
builder.Services.AddHealthChecks();

var app = builder.Build();

// Configure the HTTP request pipeline
if (app.Environment.IsDevelopment())
{
    app.UseSwagger();
    app.UseSwaggerUI();
}

// Add request logging middleware
app.Use(async (context, next) =>
{
    var logger = context.RequestServices.GetRequiredService<ILogger<Program>>();
    logger.LogInformation("Incoming request: {Method} {Path}", context.Request.Method, context.Request.Path);
    
    // Log authorization header (masked for security)
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

app.UseAuthentication();
app.UseAuthorization();

// Map health check endpoint
app.MapHealthChecks("/health");

// Map controllers
app.MapControllers();

// Root endpoint
app.MapGet("/", () => new
{
    service = "Hello World API",
    version = "1.0.0",
    status = "Running",
    endpoints = new[]
    {
        "/health - Health check endpoint",
        "/api/hello - Authenticated hello endpoint (requires valid JWT token)"
    }
});

app.Logger.LogInformation("Starting Hello World API...");
app.Logger.LogInformation("Azure AD Tenant: {TenantId}", builder.Configuration["AzureAd:TenantId"]);
app.Logger.LogInformation("Azure AD Client: {ClientId}", builder.Configuration["AzureAd:ClientId"]);

app.Run();
