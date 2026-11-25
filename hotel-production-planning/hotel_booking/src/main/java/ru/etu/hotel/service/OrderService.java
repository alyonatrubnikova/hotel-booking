package ru.etu.hotel.service;

import com.fasterxml.jackson.databind.ObjectMapper;
import lombok.RequiredArgsConstructor;
import org.springframework.stereotype.Service;
import ru.etu.hotel.repository.OrderRepository;

import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;

@Service
@RequiredArgsConstructor
public class OrderService {
    
    private final OrderRepository orderRepository;
    private final ObjectMapper objectMapper = new ObjectMapper();

    // 1. Получить параметры
    public List<Map<String, Object>> getConfigParams(Integer productId) {
        List<Object[]> results = orderRepository.getConfigParams(productId);
        List<Map<String, Object>> response = new ArrayList<>();
        for (Object[] row : results) {
            Map<String, Object> param = new HashMap<>();
            param.put("id", row[0]);
            param.put("code", row[1]);
            param.put("name", row[2]);
            param.put("type", row[3]);
            param.put("unit", row[4]);
            param.put("min", row[5]);
            param.put("max", row[6]);
            response.add(param);
        }
        return response;
    }

    // 2. Проверить ограничения
    public String checkConstraints(String classCode, Map<String, Object> params) {
        try {
            String json = objectMapper.writeValueAsString(params);
            return orderRepository.checkConstraintsOnly(classCode, json);
        } catch (Exception e) {
            throw new RuntimeException(e.getMessage());
        }
    }

    // 3. Получить документ заказа
    public List<Map<String, Object>> getOrderDetails(Integer orderId) {
        List<Object[]> results = orderRepository.getOrderDetails(orderId);
        List<Map<String, Object>> response = new ArrayList<>();
        for (Object[] row : results) {
            Map<String, Object> item = new HashMap<>();
            item.put("orderId", row[0]);
            item.put("orderNumber", row[1]);
            item.put("customerName", row[2]);
            item.put("orderDate", row[3]);
            item.put("positionId", row[4]);
            item.put("productName", row[5]);
            item.put("quantity", row[6]);
            item.put("params", row[7]);
            response.add(item);
        }
        return response;
    }
    
    // 4. Создать заказ
    public Integer createOrder(String customerName, String classCode, Map<String, Object> params) {
        try {
            String paramsJson = objectMapper.writeValueAsString(params);
            return orderRepository.createCustomOrder(customerName, classCode, paramsJson);
        } catch (Exception e) {
            throw new RuntimeException(e.getMessage());
        }
    }
        // Метод для получения реестра всех заказов
    public List<Map<String, Object>> getAllOrders() {
        List<Object[]> results = orderRepository.getAllOrders();
        List<Map<String, Object>> response = new ArrayList<>();
        
        for (Object[] row : results) {
            Map<String, Object> order = new HashMap<>();
            order.put("orderId", row[0]);
            order.put("orderNumber", row[1]);
            order.put("customerName", row[2]);
            order.put("orderDate", row[3]);
            order.put("status", row[4]);
            order.put("totalItems", row[5]);
            order.put("totalPrice", row[6]);
            response.add(order);
        }
        return response;
    }
}