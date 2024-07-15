Based on your screenshots and the issue you're facing with calling `GetFutureContracts`, you need to retrieve the instance of `IFutureContractProcessor` using dependency injection within a service provider class and then use that to call the `GetFutureContracts` method.

Here's an approach to achieve this:

1. **Ensure your `IFutureContractProcessor` is registered in your dependency injection container:**

```csharp
builder.Services.AddScoped<IFutureContractProcessor, FutureContractProcessor>();
```

2. **Create a service provider class to handle the initialization logic:**

```csharp
public class MassTransitConfigurator
{
    private readonly IFutureContractProcessor _futureContractProcessor;

    public MassTransitConfigurator(IFutureContractProcessor futureContractProcessor)
    {
        _futureContractProcessor = futureContractProcessor;
    }

    public async Task ConfigureAsync()
    {
        var futureContracts = await _futureContractProcessor.GetFutureContracts();
        var consumerConfigs = new List<(string QueueName, Type ConsumerType)>
        {
            ("orders", typeof(RequestResponseConsumer<AmiusOrder, AmiusOrder>)),
            ("orders", typeof(RequestResponseConsumer<string, OrderSummary>)),
            ("orders", typeof(RequestResponseConsumer<string, ADL.Amius.TT.Model.TtAccount>))
        };

        // Assuming messageConfig is defined elsewhere or passed as a parameter
        services.AddMassTransitWithConfig(
            messageConfig,
            consumerConfigs);
    }
}
```

3. **Modify the `Program.cs` to use the service provider class for initialization:**

```csharp
var builder = WebApplication.CreateBuilder(args);

// Bind configuration to MySettings
builder.Services.Configure<MySettings>(builder.Configuration.GetSection("MySettings"));

// Register the repository and service
builder.Services.AddScoped<IFutureContractProcessor, FutureContractProcessor>();
builder.Services.AddScoped<MassTransitConfigurator>();

var app = builder.Build();

// Access the service provider through the IServiceProvider and initialize
using (var scope = app.Services.CreateScope())
{
    var configurator = scope.ServiceProvider.GetRequiredService<MassTransitConfigurator>();
    await configurator.ConfigureAsync();
}

app.Run();
```

This code ensures that:

1. **Dependency Injection**: `IFutureContractProcessor` is registered and injected into `MassTransitConfigurator`.
2. **Async Configuration**: The `ConfigureAsync` method in `MassTransitConfigurator` retrieves the future contracts and configures MassTransit with the appropriate consumer configurations.
3. **Program.cs**: The `MassTransitConfigurator` is used during the application startup to perform the necessary configuration.

Ensure that `messageConfig` is defined appropriately or passed to the `ConfigureAsync` method as needed.

With this setup, the logic to retrieve the list of integers and configure MassTransit is encapsulated within the `MassTransitConfigurator` class, keeping the `Program.cs` file clean and focused on the application startup process.