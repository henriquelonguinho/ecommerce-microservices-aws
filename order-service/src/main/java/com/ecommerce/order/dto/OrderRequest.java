package com.ecommerce.order.dto;

import jakarta.validation.constraints.Email;
import jakarta.validation.constraints.NotBlank;
import jakarta.validation.constraints.NotEmpty;
import jakarta.validation.constraints.Positive;
import lombok.AllArgsConstructor;
import lombok.Builder;
import lombok.Data;
import lombok.NoArgsConstructor;

import java.math.BigDecimal;
import java.util.List;

@Data
@Builder
@NoArgsConstructor
@AllArgsConstructor
public class OrderRequest {

    @NotBlank(message = "Customer name is required")
    private String customerName;

    @Email(message = "Valid email is required")
    @NotBlank(message = "Customer email is required")
    private String customerEmail;

    @NotEmpty(message = "At least one item is required")
    private List<OrderItem> items;

    @Data
    @Builder
    @NoArgsConstructor
    @AllArgsConstructor
    public static class OrderItem {
        @NotBlank(message = "Product name is required")
        private String productName;

        @Positive(message = "Quantity must be positive")
        private int quantity;

        @Positive(message = "Price must be positive")
        private BigDecimal unitPrice;
    }
}
