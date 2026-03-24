package com.ecommerce.notification.service;

import com.ecommerce.notification.event.PaymentCompletedEvent;
import lombok.RequiredArgsConstructor;
import lombok.extern.slf4j.Slf4j;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;
import software.amazon.awssdk.services.ses.SesClient;
import software.amazon.awssdk.services.ses.model.*;

@Slf4j
@Service
@RequiredArgsConstructor
public class EmailService {

    private final SesClient sesClient;

    @Value("${app.ses.from-email}")
    private String fromEmail;

    public void sendOrderConfirmation(PaymentCompletedEvent event) {
        String subject = String.format("Order Confirmation - %s", event.getOrderId());
        String body = buildEmailBody(event);

        try {
            SendEmailRequest request = SendEmailRequest.builder()
                    .source(fromEmail)
                    .destination(Destination.builder()
                            .toAddresses(event.getCustomerEmail())
                            .build())
                    .message(Message.builder()
                            .subject(Content.builder().data(subject).charset("UTF-8").build())
                            .body(Body.builder()
                                    .html(Content.builder().data(body).charset("UTF-8").build())
                                    .build())
                            .build())
                    .build();

            sesClient.sendEmail(request);
            log.info("Email sent to {} for orderId={}", event.getCustomerEmail(), event.getOrderId());
        } catch (SesException e) {
            log.error("Failed to send email for orderId={}: {}", event.getOrderId(), e.getMessage());
            throw new RuntimeException("Failed to send confirmation email", e);
        }
    }

    private String buildEmailBody(PaymentCompletedEvent event) {
        return String.format("""
                <html>
                <body>
                    <h2>Order Confirmation</h2>
                    <p>Dear %s,</p>
                    <p>Your order <strong>%s</strong> has been confirmed.</p>
                    <p>Payment of <strong>$%s</strong> was <strong>%s</strong>.</p>
                    <p>Payment ID: %s</p>
                    <p>Thank you for your purchase.</p>
                </body>
                </html>
                """,
                event.getCustomerName(),
                event.getOrderId(),
                event.getAmount(),
                event.getStatus(),
                event.getPaymentId());
    }
}
