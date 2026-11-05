import 'app_failure.dart';

/// Turns a refusal from the cart and order functions into a message for the
/// buyer.
String buyingFailureMessage(AppFailure failure) {
  if (failure is! ServerFailure) return failure.message;
  return switch (failure.code) {
    'OWN_PRODUCT' => 'This is your own listing, so you can\'t buy it.',
    'PRODUCT_UNAVAILABLE' => 'This product is no longer available.',
    'OUT_OF_STOCK' => 'Sorry, there isn\'t enough stock left.',
    'STOCK_LIMIT' => 'You already have all the available stock in your cart.',
    'CART_FULL' => 'Your cart is full. Please remove something first.',
    'CART_EMPTY' => 'Your cart is empty.',
    'CART_ITEM_NOT_FOUND' => 'This item is no longer in your cart.',
    'PRICE_CHANGED' =>
      'A price or delivery fee has changed. Please check the new total.',
    'COD_LIMIT_EXCEEDED' => 'This order is over the Cash on Delivery limit. Please order fewer items.',
    'PHONE_NOT_VERIFIED' => 'Please verify your phone number first.',
    'ADDRESS_NOT_FOUND' => 'Please choose another delivery address.',
    'ACCOUNT_SUSPENDED' => 'Your account is suspended. Please contact support.',
    'ORDER_NOT_FOUND' => 'We could not find this order.',
    'ORDER_NOT_CANCELLABLE' =>
      'This order can no longer be cancelled, because it is on its way.',
    _ => failure.message,
  };
}
