package com.ecommerce.order.service;

import com.ecommerce.order.dto.OrderRequest;
import com.ecommerce.order.dto.OrderResponse;
import com.ecommerce.order.event.OrderCreatedEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import java.math.BigDecimal;
import java.time.Instant;
import java.util.*;
import java.util.concurrent.ConcurrentHashMap;

@Slf4j
@Service
@RequiredArgsConstructor
public class OrderService {

    private final SnsClient snsClient;
    private final ObjectMapper objectMapper;
    private final Map<String, OrderResponse> orders = new ConcurrentHashMap<>();

    @Value("${app.sns.order-created-topic-arn}")
    private String orderCreatedTopicArn;

    public OrderResponse createOrder(OrderRequest request) {
        String orderId = UUID.randomUUID().toString();
        Instant now = Instant.now();

        BigDecimal totalAmount = request.getItems().stream()
                .map(item -> item.getUnitPrice().multiply(BigDecimal.valueOf(item.getQuantity())))
                .reduce(BigDecimal.ZERO, BigDecimal::add);

        OrderCreatedEvent event = OrderCreatedEvent.builder()
                .orderId(orderId)
                .customerName(request.getCustomerName())
                .customerEmail(request.getCustomerEmail())
                .totalAmount(totalAmount)
                .items(request.getItems().stream()
                        .map(i -> OrderCreatedEvent.Item.builder()
                                .productName(i.getProductName())
                                .quantity(i.getQuantity())
                                .unitPrice(i.getUnitPrice())
                                .build())
                        .toList())
                .createdAt(now)
                .build();

        publishEvent(event);

        log.info("Order created: orderId={}, totalAmount={}", orderId, totalAmount);

        OrderResponse response = OrderResponse.builder()
                .orderId(orderId)
                .status("CREATED")
                .totalAmount(totalAmount)
                .createdAt(now)
                .build();

        orders.put(orderId, response);

        return response;
    }

    public Optional<OrderResponse> getOrder(String orderId) {
        return Optional.ofNullable(orders.get(orderId));
    }

    public List<OrderResponse> getAllOrders() {
        return new ArrayList<>(orders.values());
    }

    private void publishEvent(OrderCreatedEvent event) {
        try {
            String payload = objectMapper.writeValueAsString(event);
            snsClient.publish(PublishRequest.builder()
                    .topicArn(orderCreatedTopicArn)
                    .message(payload)
                    .subject("OrderCreated")
                    .build());
            log.info("Published OrderCreatedEvent: orderId={}", event.getOrderId());
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize OrderCreatedEvent", e);
            throw new RuntimeException("Failed to publish order event", e);
        }
    }
}
