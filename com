using System;
using System.Collections.Generic;
using MassTransit;

public static class CommonBusConfigurator
{
    public static void ConfigureBus<TMessage, TConsumer>(IBusRegistrationConfigurator configurator, MessagingConfig config, Func<ConsumeContext<TMessage>, bool> filterPredicate)
        where TMessage : class
        where TConsumer : class, IConsumer<TMessage>
    {
        switch (config.Transport)
        {
            case TransportType.RabbitMQ:
                configurator.UsingRabbitMq((context, cfg) =>
                {
                    JsonConfigurator.ConfigureJsonSerializerOptionsRabbitMq(cfg);

                    cfg.Host(config.ConnectionString, h =>
                    {
                        h.Username(config.UserName);
                        h.Password(config.Password);
                    });

                    cfg.ReceiveEndpoint(config.ReceiverQueue, e =>
                    {
                        if (filterPredicate != null)
                        {
                            e.UseFilter(new FilterMiddleware<TMessage>(filterPredicate));
                        }

                        if (!string.IsNullOrEmpty(config.ExchangeName))
                        {
                            e.Bind(config.ExchangeName, s =>
                            {
                                s.ExchangeType = "fanout";
                            });
                        }
                    });
                });
                break;

            case TransportType.AzureServiceBus:
                configurator.UsingAzureServiceBus((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString);

                    cfg.SubscriptionEndpoint<TMessage>(config.ReceiverQueue, e =>
                    {
                        JsonConfigurator.ConfigureJsonSerializerOptionsServiceBus(cfg);

                        if (filterPredicate != null)
                        {
                            e.UseFilter(new FilterMiddleware<TMessage>(filterPredicate));
                        }

                        e.PrefetchCount = 16;
                        e.UseMessageRetry(r => r.Interval(config.RetryCount, config.RetryInterval));
                        e.ConfigureConsumer<TConsumer>(context);
                    });
                });
                break;

            default:
                throw new ArgumentException("Invalid transport type");
        }
    }

    public static void ConfigureBus(IBusRegistrationConfigurator configurator, MessagingConfig config)
    {
        switch (config.Transport)
        {
            case TransportType.RabbitMQ:
                configurator.UsingRabbitMq((context, cfg) =>
                {
                    JsonConfigurator.ConfigureJsonSerializerOptionsRabbitMq(cfg);

                    cfg.Host(config.ConnectionString, h =>
                    {
                        h.Username(config.UserName);
                        h.Password(config.Password);
                    });

                    // Add other configurations if needed

                    // cfg.ConfigureEndpoints(context);
                });
                break;

            case TransportType.AzureServiceBus:
                configurator.UsingAzureServiceBus((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString);

                    cfg.SubscriptionEndpoint<TMessage>(config.ReceiverQueue, e =>
                    {
                        JsonConfigurator.ConfigureJsonSerializerOptionsServiceBus(cfg);

                        if (filterPredicate != null)
                        {
                            e.UseFilter(new FilterMiddleware<TMessage>(filterPredicate));
                        }

                        e.PrefetchCount = 16;
                        e.UseMessageRetry(r => r.Interval(config.RetryCount, config.RetryInterval));
                        e.ConfigureConsumer<TConsumer>(context);
                    });
                });
                break;

            default:
                throw new ArgumentException("Invalid transport type");
        }
    }

    public static void ConfigureBus(IBusRegistrationConfigurator configurator, MessagingConfig config, List<(Type requestType, Type responseType)> consumerConfig)
    {
        switch (config.Transport)
        {
            case TransportType.RabbitMQ:
                configurator.UsingRabbitMq((context, cfg) =>
                {
                    JsonConfigurator.ConfigureJsonSerializerOptionsRabbitMq(cfg);

                    cfg.Host(config.ConnectionString, h =>
                    {
                        h.Username(config.UserName);
                        h.Password(config.Password);
                    });

                    foreach (var (requestType, responseType) in consumerConfig)
                    {
                        cfg.ReceiveEndpoint(config.ReceiverQueue, e =>
                        {
                            var consumerType = typeof(GenericConsumer<>).MakeGenericType(requestType);
                            e.ConfigureConsumer(context, consumerType);

                            e.PrefetchCount = 16;
                            e.UseMessageRetry(r => r.Interval(config.RetryCount, config.RetryInterval));
                        });
                    }
                });
                break;

            case TransportType.AzureServiceBus:
                configurator.UsingAzureServiceBus((context, cfg) =>
                {
                    cfg.Host(config.ConnectionString);

                    foreach (var (requestType, responseType) in consumerConfig)
                    {
                        cfg.SubscriptionEndpoint<TMessage>(config.ReceiverQueue, e =>
                        {
                            JsonConfigurator.ConfigureJsonSerializerOptionsServiceBus(cfg);

                            var consumerType = typeof(GenericConsumer<>).MakeGenericType(requestType);
                            e.ConfigureConsumer(context, consumerType);

                            e.PrefetchCount = 16;
                            e.UseMessageRetry(r => r.Interval(config.RetryCount, config.RetryInterval));
                        });
                    }
                });
                break;

            default:
                throw new ArgumentException("Invalid transport type");
        }
    }
}