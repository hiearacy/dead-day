/// A discovered item is a world fact; possession is a separate engine fact.
class ItemStack {
  const ItemStack({required this.elementId, required this.quantity});
  final String elementId;
  final int quantity;

  Map<String, dynamic> toJson() =>
      {'elementId': elementId, 'quantity': quantity};

  factory ItemStack.fromJson(Map<String, dynamic> json) => ItemStack(
        elementId: json['elementId'] as String,
        quantity: (json['quantity'] as num?)?.toInt() ?? 1,
      );
}
