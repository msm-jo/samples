using MassTransit;
using System.Threading.Tasks;

public class GenericPublisher<TRequest>
    where TRequest : class
{
    private readonly IPublishEndpoint _publishEndpoint;

    public GenericPublisher(IPublishEndpoint publishEndpoint)
    {
        _publishEndpoint = publishEndpoint;
    }

    public async Task Publish(TRequest request)
    {
        await _publishEndpoint.Publish(request);
    }
}

using MassTransit;
using Microsoft.Extensions.DependencyInjection;
using System;
using System.Collections.Generic;

public static class MassTransitExtensions
{
    public static IServiceCollection AddMassTransitConsumers(this IServiceCollection services, MessagingConfig config, List<(Type consumerType, string queueName, Type requestType)> consumerConfig)
    {
        services.AddMassTransit(x =>
        {
            foreach (var (consumerType, _, _) in consumerConfig)
            {
                x.AddConsumer(consumerType);
            }

            if (config.Transport == TransportType.RabbitMQ)
            {
                x.UsingRabbitMq((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString, h =>
                    {
                        h.Username(config.UserName);
                        h.Password(config.Password);
                    });

                    foreach (var (consumerType, queueName, _) in consumerConfig)
                    {
                        cfg.ReceiveEndpoint(queueName, e =>
                        {
                            e.ConfigureConsumer(context, consumerType);
                        });
                    }
                });
            }
            else if (config.Transport == TransportType.AzureServiceBus)
            {
                x.UsingAzureServiceBus((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString);

                    foreach (var (consumerType, queueName, requestType) in consumerConfig)
                    {
                        var method = typeof(IServiceBusBusFactoryConfigurator)
                            .GetMethod("SubscriptionEndpoint", new[] { typeof(string), typeof(Action<IServiceBusSubscriptionEndpointConfigurator>) })
                            ?.MakeGenericMethod(requestType);
                        
                        method?.Invoke(cfg, new object[] { queueName, new Action<IServiceBusSubscriptionEndpointConfigurator>(e =>
                        {
                            e.ConfigureConsumer(context, consumerType);
                        }) });
                    }
                });
            }
        });

        // Register the message stores for each request type
        foreach (var (_, _, requestType) in consumerConfig)
        {
            var messageStoreType = typeof(MessageStore<>).MakeGenericType(requestType);
            var iMessageStoreType = typeof(IMessageStore<>).MakeGenericType(requestType);
            services.AddSingleton(iMessageStoreType, messageStoreType);
        }

        services.AddMassTransitHostedService();

        return services;
    }

    public static IServiceCollection AddMassTransitPublishers(this IServiceCollection services, MessagingConfig config, List<Type> publisherRequestTypes)
    {
        services.AddMassTransit(x =>
        {
            if (config.Transport == TransportType.RabbitMQ)
            {
                x.UsingRabbitMq((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString, h =>
                    {
                        h.Username(config.UserName);
                        h.Password(config.Password);
                    });
                });
            }
            else if (config.Transport == TransportType.AzureServiceBus)
            {
                x.UsingAzureServiceBus((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString);
                });
            }
        });

        foreach (var requestType in publisherRequestTypes)
        {
            var publisherType = typeof(GenericPublisher<>).MakeGenericType(requestType);
            services.AddSingleton(publisherType);
        }

        services.AddMassTransitHostedService();

        return services;
    }
}

using Microsoft.Extensions.DependencyInjection;
using Microsoft.Extensions.Hosting;
using System;
using System.Collections.Generic;

var builder = WebApplication.CreateBuilder(args);

// Load configuration
var config = builder.Configuration.GetSection("MessagingConfig").Get<MessagingConfig>();

// Register MassTransit consumers
builder.Services.AddMassTransitConsumers(config, new List<(Type, string, Type)>
{
    (typeof(ConsumerWithResponse<BasketQuoteRequest, BasketQuoteResponse>), "basket-quote-queue", typeof(BasketQuoteRequest)),
    (typeof(ConsumerWithResponse<AnotherRequest, AnotherResponse>), "another-request-queue", typeof(AnotherRequest))
});

// Register MassTransit publishers
builder.Services.AddMassTransitPublishers(config, new List<Type>
{
    typeof(BasketQuoteRequest),
    typeof(AnotherRequest)
});

var app = builder.Build();

app.MapPost("/publish/basketquote", async (BasketQuoteRequest request, GenericPublisher<BasketQuoteRequest> publisher) =>
{
    await publisher.Publish(request);
    return Results.Ok();
});

app.MapPost("/publish/another", async (AnotherRequest request, GenericPublisher<AnotherRequest> publisher) =>
{
    await publisher.Publish(request);
    return Results.Ok();
});

app.Run();