import 'package:spicy/features/order_tracking/domain/entities/order.dart';
import 'package:spicy/features/cart/domain/entities/cart_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item.dart';
import 'package:spicy/features/menu/domain/entities/menu_item_variant.dart';

class MockOrderDataSource {
  final List<Order> _orders = [
    Order(
      id: 'ORD-001',
      items: const [
        CartItem(
          menuItem: MenuItem(
            id: 'mns-1',
            name: 'Wagyu Ribeye',
            description: 'A5 Japanese Wagyu ribeye, 12oz.',
            displayPrice: '85 руб',
            prices: [85.00],
            heatLevel: 0,
            image:
                'https://images.unsplash.com/photo-1600891964092-4316c288032e?w=600',
            category: 'Main Course',
          ),
          variant: MenuItemVariant(
            id: 'mns-1-standard',
            name: 'Standard',
            code: 'standard',
            priceKopeks: 8500,
          ),
          quantity: 1,
        ),
        CartItem(
          menuItem: MenuItem(
            id: 'dst-1',
            name: 'Molten Chocolate Fondant',
            description: 'Rich Valrhona dark chocolate cake.',
            displayPrice: '16 руб',
            prices: [16.00],
            heatLevel: 0,
            image:
                'https://images.unsplash.com/photo-1606313564200-e75d5e30476c?w=600',
            category: 'Desserts',
          ),
          variant: MenuItemVariant(
            id: 'dst-1-standard',
            name: 'Standard',
            code: 'standard',
            priceKopeks: 1600,
          ),
          quantity: 2,
        ),
      ],
      totalPrice: 117.00,
      status: OrderStatus.onTheWay,
      createdAt: DateTime.now().subtract(const Duration(minutes: 45)),
      estimatedDelivery: DateTime.now().add(const Duration(minutes: 15)),
      deliveryAddress: '123 Olaya Street, Riyadh',
      driverLatitude: 24.7100,
      driverLongitude: 46.6750,
      restaurantLatitude: 24.7136,
      restaurantLongitude: 46.6753,
    ),
    Order(
      id: 'ORD-002',
      items: const [
        CartItem(
          menuItem: MenuItem(
            id: 'mns-2',
            name: 'Lobster Risotto',
            description: 'Slow-cooked Arborio rice with lobster.',
            displayPrice: '48 руб',
            prices: [48.00],
            heatLevel: 0,
            image:
                'https://images.unsplash.com/photo-1534422298391-e4f8c172dddb?w=600',
            category: 'Main Course',
          ),
          variant: MenuItemVariant(
            id: 'mns-2-standard',
            name: 'Standard',
            code: 'standard',
            priceKopeks: 4800,
          ),
          quantity: 1,
        ),
      ],
      totalPrice: 48.00,
      status: OrderStatus.delivered,
      createdAt: DateTime.now().subtract(const Duration(days: 2)),
      deliveryAddress: '456 King Fahd Road, Riyadh',
    ),
  ];

  List<Order> getOrders() => _orders;

  Order getOrderById(String id) =>
      _orders.firstWhere((order) => order.id == id);

  List<Order> getActiveOrders() =>
      _orders.where((order) => order.isActive).toList();

  Order placeOrder(Order order) {
    _orders.insert(0, order);
    return order;
  }
}
