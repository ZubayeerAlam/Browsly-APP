import 'app_failure.dart';

/// Turns a refusal from the selling functions into a message for the seller.
String sellingFailureMessage(AppFailure failure) {
  if (failure is! ServerFailure) return failure.message;
  return switch (failure.code) {
    'NOT_A_SELLER' => 'Your shop is not able to sell right now.',
    'PHONE_NOT_VERIFIED' => 'Please verify your phone number first.',
    'TERMS_NOT_ACCEPTED' => 'Please accept the seller terms to continue.',
    'INVALID_REGION' => 'Please choose your division and district.',
    'TOO_MANY_PHOTOS' => 'A listing can have at most 5 photos.',
    'INVALID_PHOTO' => 'One of the photos did not upload. Please add it again.',
    'PHOTO_REQUIRED' => 'Please add at least one photo.',
    'INVALID_CATEGORY' => 'Please choose another category.',
    'INVALID_VARIANTS' => 'Please check your colours and sizes.',
    'DESCRIPTION_REQUIRED' => 'Please write a description.',
    'PRICE_REQUIRED' => 'Please enter a price.',
    'PRODUCT_NOT_FOUND' => 'This listing is no longer available.',
    'PRODUCT_NOT_SUBMITTABLE' => 'This listing has already been submitted.',
    'PRODUCT_NOT_PAUSABLE' => 'Only live listings can be paused.',
    'COMMISSION_LIMIT' =>
      'You owe too much commission to post right now. Please pay it first. '
          'You can see the amount under Sales, then Commission.',
    'SUBMISSION_LIMIT' =>
      'You have reached today\'s limit for reviews. Please try again tomorrow.',
    _ => failure.message,
  };
}
