package com.ecommerce.payment.listener;

import com.ecommerce.payment.event.OrderCreatedEvent;
import com.ecommerce.payment.service.PaymentService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.awspring.cloud.sqs.annotation.SqsListener;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class OrderCreatedListener {

    private final PaymentService paymentService;
    private final ObjectMapper objectMapper;

    @SqsListener("${app.sqs.order-created-queue}")
    public void onOrderCreated(String rawMessage) {
        try {
            // SNS wraps the message — extract the actual payload from "Message" field
            JsonNode root = objectMapper.readTree(rawMessage);
            String payload = root.has("Message") ? root.get("Message").asText() : rawMessage;

            OrderCreatedEvent event = objectMapper.readValue(payload, OrderCreatedEvent.class);
            log.info("Received OrderCreatedEvent: orderId={}", event.getOrderId());

            paymentService.processPayment(event);
        } catch (Exception e) {
            log.error("Failed to process OrderCreatedEvent", e);
            throw new RuntimeException("Failed to process order event", e);
        }
    }
}
