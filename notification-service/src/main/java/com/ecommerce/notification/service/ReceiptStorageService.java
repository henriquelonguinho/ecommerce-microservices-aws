package com.ecommerce.notification.service;

import com.ecommerce.notification.event.PaymentCompletedEvent;
import com.fasterxml.jackson.core.JsonProcessingException;
import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.core.sync.RequestBody;
import software.amazon.awssdk.services.s3.S3Client;
import software.amazon.awssdk.services.s3.model.PutObjectRequest;

import java.time.LocalDate;

@Slf4j
@Service
@RequiredArgsConstructor
public class ReceiptStorageService {

    private final S3Client s3Client;
    private final ObjectMapper objectMapper;

    @Value("${app.s3.receipts-bucket}")
    private String receiptsBucket;

    public void storeReceipt(PaymentCompletedEvent event) {
        String key = String.format("receipts/%s/%s/%s.json",
                LocalDate.now(),
                event.getOrderId(),
                event.getPaymentId());

        try {
            String receiptJson = objectMapper.writeValueAsString(event);

            PutObjectRequest putRequest = PutObjectRequest.builder()
                    .bucket(receiptsBucket)
                    .key(key)
                    .contentType("application/json")
                    .build();

            s3Client.putObject(putRequest, RequestBody.fromString(receiptJson));
            log.info("Receipt stored: bucket={}, key={}", receiptsBucket, key);
        } catch (JsonProcessingException e) {
            log.error("Failed to serialize receipt for orderId={}", event.getOrderId(), e);
            throw new RuntimeException("Failed to store receipt", e);
        }
    }
}
