To achieve a request-response pattern where one API sends a message and another API handles the message and sends a response back, you need to set up two separate projects: one for the requester and one for the responder.

### Step 1: Define Shared Library

Create a shared library project to define your message types.

**SharedLibrary/MessageTypes.cs:**

```csharp
public class RequestMessage<TRequest>
{
    public TRequest Payload { get; set; }
    public Guid CorrelationId { get; set; }
}

public class ResponseMessage<TResponse>
{
    public TResponse Payload { get; set; }
    public Guid CorrelationId { get; set; }
}

public class YourRequestType
{
    public string Value { get; set; }
}

public class YourResponseType
{
    public string Result { get; set; }
}
```

### Step 2: Responder API

This API will handle the incoming message and send back a response.

1. **Program.cs or Startup.cs**

```csharp
var builder = WebApplication.CreateBuilder(args);

// Load configuration from appsettings.json
builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
var messagingConfig = builder.Configuration.GetSection("MessagingConfig").Get<MessagingConfig>();

// Register MassTransit and configure RabbitMQ
builder.Services.AddMassTransit(x =>
{
    x.AddConsumer<GenericConsumer<YourRequestType, YourResponseType>>();

    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(messagingConfig.Host);

        cfg.ReceiveEndpoint("request-queue", e =>
        {
            e.ConfigureConsumer<GenericConsumer<YourRequestType, YourResponseType>>(context);
        });
    });
});

builder.Services.AddMassTransitHostedService();

var app = builder.Build();

app.Run();
```

2. **appsettings.json**

Ensure you have the necessary RabbitMQ settings.

```json
{
    "MessagingConfig": {
        "Host": "rabbitmq://localhost"
    }
}
```

3. **GenericConsumer.cs**

Implement the generic consumer.

```csharp
public class GenericConsumer<TRequest, TResponse> : IConsumer<RequestMessage<TRequest>>
    where TRequest : class
    where TResponse : class, new()
{
    public async Task Consume(ConsumeContext<RequestMessage<TRequest>> context)
    {
        var request = context.Message;

        // Create a response
        var response = new ResponseMessage<TResponse>
        {
            Payload = new TResponse { Result = "Processed" } as TResponse, // Simplified response generation
            CorrelationId = request.CorrelationId
        };

        // Send the response back
        await context.RespondAsync(response);
    }
}
```

### Step 3: Requester API

This API will send the message and wait for the response.

1. **Program.cs or Startup.cs**

```csharp
var builder = WebApplication.CreateBuilder(args);

// Load configuration from appsettings.json
builder.Configuration.AddJsonFile("appsettings.json", optional: false, reloadOnChange: true);
var messagingConfig = builder.Configuration.GetSection("MessagingConfig").Get<MessagingConfig>();

// Register MassTransit and configure RabbitMQ
builder.Services.AddMassTransit(x =>
{
    x.UsingRabbitMq((context, cfg) =>
    {
        cfg.Host(messagingConfig.Host);
    });
});

builder.Services.AddMassTransitHostedService();
builder.Services.AddScoped<MessagePublisher>();

var app = builder.Build();

// Example usage endpoint
app.MapPost("/send-request", async (MessagePublisher publisher, YourRequestType requestPayload) =>
{
    var response = await publisher.SendRequestAsync(requestPayload);
    return Results.Ok(response);
});

app.Run();
```

2. **appsettings.json**

Ensure you have the necessary RabbitMQ settings.

```json
{
    "MessagingConfig": {
        "Host": "rabbitmq://localhost"
    }
}
```

3. **MessagePublisher.cs**

Implement the message publisher.

```csharp
public class MessagePublisher
{
    private readonly IRequestClient<RequestMessage<YourRequestType>> _requestClient;
    private readonly ILogger<MessagePublisher> _logger;

    public MessagePublisher(IRequestClient<RequestMessage<YourRequestType>> requestClient, ILogger<MessagePublisher> logger)
    {
        _requestClient = requestClient;
        _logger = logger;
    }

    public async Task<ResponseMessage<YourResponseType>> SendRequestAsync(YourRequestType requestPayload)
    {
        try
        {
            var requestMessage = new RequestMessage<YourRequestType>
            {
                Payload = requestPayload,
                CorrelationId = Guid.NewGuid()
            };

            var response = await _requestClient.GetResponse<ResponseMessage<YourResponseType>>(requestMessage);
            return response.Message;
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Error occurred while sending request message.");
            throw;
        }
    }
}
```

### Summary

1. **Shared Library**: Defines the message types used by both APIs.
2. **Responder API**:
   - Configures MassTransit with RabbitMQ.
   - Implements a generic consumer to handle requests and send responses.
3. **Requester API**:
   - Configures MassTransit with RabbitMQ.
   - Implements a message publisher to send requests and handle responses.

This setup allows one API to send a message and receive a response from another API. Ensure the correct message types and configurations are in place to handle the request-response communication. Adjust the code to fit your specific requirements.