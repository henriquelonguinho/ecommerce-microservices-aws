package com.ecommerce.notification.listener;

import com.ecommerce.notification.event.PaymentCompletedEvent;
import com.ecommerce.notification.service.EmailService;
import com.ecommerce.notification.service.ReceiptStorageService;
import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import io.awspring.cloud.sqs.annotation.SqsListener;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.stereotype.Component;

@Slf4j
@Component
@RequiredArgsConstructor
public class PaymentCompletedListener {

    private final EmailService emailService;
    private final ReceiptStorageService receiptStorageService;
    private final ObjectMapper objectMapper;

    @SqsListener("${app.sqs.payment-completed-queue}")
    public void onPaymentCompleted(String rawMessage) {
        try {
            // SNS wraps the message — extract the actual payload from "Message" field
            JsonNode root = objectMapper.readTree(rawMessage);
            String payload = root.has("Message") ? root.get("Message").asText() : rawMessage;

            PaymentCompletedEvent event = objectMapper.readValue(payload, PaymentCompletedEvent.class);
            log.info("Received PaymentCompletedEvent: orderId={}, paymentId={}", event.getOrderId(), event.getPaymentId());

            receiptStorageService.storeReceipt(event);
            emailService.sendOrderConfirmation(event);

            log.info("Notification processing complete for orderId={}", event.getOrderId());
        } catch (Exception e) {
            log.error("Failed to process PaymentCompletedEvent", e);
            throw new RuntimeException("Failed to process payment event", e);
        }
    }
}
