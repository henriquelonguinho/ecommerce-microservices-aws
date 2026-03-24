package com.ecommerce.payment.service;

import com.ecommerce.payment.event.OrderCreatedEvent;
import com.ecommerce.payment.event.PaymentCompletedEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.sns.SnsClient;
import software.amazon.awssdk.services.sns.model.PublishRequest;

import java.time.Instant;
import java.util.UUID;

@Slf4j
@Service
@RequiredArgsConstructor
public class PaymentService {

    private final SnsClient snsClient;
    private final ObjectMapper objectMapper;

    @Value("${app.sns.payment-completed-topic-arn}")
    private String paymentCompletedTopicArn;

    public void processPayment(OrderCreatedEvent orderEvent) {
        log.info("Processing payment for orderId={}, amount={}", orderEvent.getOrderId(), orderEvent.getTotalAmount());

        String paymentId = UUID.randomUUID().toString();
        String status = "APPROVED";

        PaymentCompletedEvent paymentEvent = PaymentCompletedEvent.builder()
                .paymentId(paymentId)
                .orderId(orderEvent.getOrderId())
                .customerName(orderEvent.getCustomerName())
                .customerEmail(orderEvent.getCustomerEmail())
                .amount(orderEvent.getTotalAmount())
                .status(status)
                .processedAt(Instant.now())
                .build();

        publishEvent(paymentEvent);

        log.info("Payment processed: paymentId={}, orderId={}, status={}", paymentId, orderEvent.getOrderId(), status);
    }

    private void publishEvent(PaymentCompletedEvent event) {
        try {
            String payload = objectMapper.writeValueAsString(event);
            snsClient.publish(PublishRequest.builder()
                    .topicArn(paymentCompletedTopicArn)
                    .message(payload)
                    .subject("PaymentCompleted")
                    .build());
            log.info("Published PaymentCompletedEvent: paymentId={}", event.getPaymentId());
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize PaymentCompletedEvent", e);
            throw new RuntimeException("Failed to publish payment event", e);
        }
    }
}
