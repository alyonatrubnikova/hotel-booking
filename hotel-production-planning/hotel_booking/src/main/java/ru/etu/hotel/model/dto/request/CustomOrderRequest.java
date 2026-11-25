package ru.etu.hotel.model.dto.request;

import lombok.Data;
import java.util.Map;

@Data
public class CustomOrderRequest {
    private String customerName;
    private Integer baseProductId;
    private Map<String, Object> params; // Сюда передадим GUESTS, CATEGORY, FOOD
}