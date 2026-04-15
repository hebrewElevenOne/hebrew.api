using System.Text;

var builder = WebApplication.CreateBuilder(args);

// Add services to the container.
builder.Services.AddHealthChecks();

builder.Services.AddControllers();
builder.Services.AddEndpointsApiExplorer(); // Required for discovering endpoints
builder.Services.AddSwaggerGen(); // Adds the Swagger generator

// Learn more about configuring OpenAPI at https://aka.ms/aspnet/openapi
builder.Services.AddOpenApi();

var app = builder.Build();
if (app.Environment.IsDevelopment())
{
    app.Use(async (context, next) =>
    {
        if (context.Request.Path.StartsWithSegments("/swagger"))
        {
            string authHeader = context.Request.Headers["Authorization"];
    
            if (authHeader != null && authHeader.StartsWith("Basic "))
            {
                var encodedCredentials = authHeader.Substring(6).Trim();
                var credentials = Encoding.UTF8.GetString(Convert.FromBase64String(encodedCredentials)).Split(':');
                
                // GET FROM ENVIRONMENT VARIABLES
                var envUser = Environment.GetEnvironmentVariable("SWAGGER_USER");
                var envPass = Environment.GetEnvironmentVariable("SWAGGER_PASS");
    
                if (credentials[0] == envUser && credentials[1] == envPass)
                {
                    await next();
                    return;
                }
            }
    
            context.Response.Headers["WWW-Authenticate"] = "Basic";
            context.Response.StatusCode = 401;
        }
        else
        {
            await next();
        }
    });
}
app.MapHealthChecks("/health");

// Configure the HTTP request pipeline.
if (app.Environment.IsDevelopment())
{
    app.MapOpenApi();
    app.UseSwagger();
    app.UseSwaggerUI(options =>
    {
        options.SwaggerEndpoint("/swagger/v1/swagger.json", "v1");
        options.RoutePrefix = "swagger"; // This makes Swagger the root of the site
    });
}



app.UseHttpsRedirection();

app.UseAuthorization();

app.MapControllers();

app.Run();
