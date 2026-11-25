package ru.etu.hotel.repository;

import org.springframework.data.jpa.repository.JpaRepository;
import org.springframework.data.jpa.repository.Query;
import org.springframework.data.repository.query.Param;
import org.springframework.stereotype.Repository;
import ru.etu.hotel.model.entity.Product;

import java.util.List;

@Repository
public interface OrderRepository extends JpaRepository<Product, Integer> {

    // Создание заказа
    @Query(value = "SELECT create_custom_order(:customerName, :classCode, CAST(:params AS jsonb))", nativeQuery = true)
    Integer createCustomOrder(
        @Param("customerName") String customerName,
        @Param("classCode") String classCode,
        @Param("params") String paramsJson
    );

    // Проверка ограничений (без создания)
    @Query(value = "SELECT check_variant_constraints(:classCode, CAST(:params AS jsonb))", nativeQuery = true)
    String checkConstraintsOnly(
        @Param("classCode") String classCode,
        @Param("params") String paramsJson
    );

    // Получить параметры
    @Query(value = "SELECT * FROM get_config_params(:productId)", nativeQuery = true)
    List<Object[]> getConfigParams(@Param("productId") Integer productId);

    // Вывод документа заказа
    @Query(value = "SELECT * FROM get_order_details(:orderId)", nativeQuery = true)
    List<Object[]> getOrderDetails(@Param("orderId") Integer orderId);

    // Получить список всех заказов
    @Query(value = "SELECT * FROM get_all_orders()", nativeQuery = true)
    List<Object[]> getAllOrders();
}