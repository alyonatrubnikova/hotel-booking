package ru.etu.hotel.controller;

import lombok.RequiredArgsConstructor;
import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import ru.etu.hotel.model.dto.response.IdResponse;
import ru.etu.hotel.service.OrderService;

import java.util.List;
import java.util.Map;

@RestController
@RequestMapping("/api")
@RequiredArgsConstructor
public class OrderController {

    private final OrderService orderService;

    @GetMapping("/products/{id}/config-params")
    public ResponseEntity<?> getConfigParams(@PathVariable Integer id) {
        return ResponseEntity.ok(orderService.getConfigParams(id));
    }

    @PostMapping("/products/check-params")
    public ResponseEntity<?> checkParams(@RequestBody Map<String, Object> request) {
        try {
            String classCode = (String) request.get("classCode");
            Map<String, Object> params = (Map<String, Object>) request.get("params");
            
            String errors = orderService.checkConstraints(classCode, params);
            if (errors != null && !errors.isEmpty()) {
                return ResponseEntity.badRequest().body(Map.of("errors", errors));
            }
            return ResponseEntity.ok(Map.of("message", "Все проверки пройдены"));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("errors", e.getMessage()));
        }
    }

    @PostMapping("/orders/create-custom")
    public ResponseEntity<?> createCustomOrder(@RequestBody Map<String, Object> request) {
        try {
            String customerName = (String) request.get("customerName");
            String classCode = (String) request.get("classCode");
            Map<String, Object> params = (Map<String, Object>) request.get("params");
            
            Integer orderId = orderService.createOrder(customerName, classCode, params);
            return ResponseEntity.status(HttpStatus.CREATED).body(new IdResponse(orderId));
        } catch (Exception e) {
            return ResponseEntity.badRequest().body(Map.of("error", e.getMessage()));
        }
    }

    @GetMapping("/orders/{id}")
    public ResponseEntity<?> getOrder(@PathVariable Integer id) {
        return ResponseEntity.ok(orderService.getOrderDetails(id));
    }

    @GetMapping("/orders")
    public ResponseEntity<?> getAllOrders() {
        // Вызываем правильный метод сервиса
        return ResponseEntity.ok(orderService.getAllOrders());
    }
}