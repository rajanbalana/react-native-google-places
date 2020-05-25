#import "RCTConvert+RNGPAutocompleteTypeFilter.h"
#import <GooglePlaces/GooglePlaces.h>
#import <GoogleMapsBase/GoogleMapsBase.h>

@implementation RCTConvert (RNGPAutocompleteTypeFilter)

RCT_ENUM_CONVERTER(GMSPlacesAutocompleteTypeFilter,
  (@{
    @"noFilter" : @(kGMSPlacesAutocompleteTypeFilterNoFilter),
    @"geocode" : @(kGMSPlacesAutocompleteTypeFilterGeocode),
    @"address" : @(kGMSPlacesAutocompleteTypeFilterAddress),
    @"establishment" : @(kGMSPlacesAutocompleteTypeFilterEstablishment),
    @"regions" : @(kGMSPlacesAutocompleteTypeFilterRegion),
    @"cities" : @(kGMSPlacesAutocompleteTypeFilterCity),
  }),
  kGMSPlacesAutocompleteTypeFilterNoFilter, integerValue
)

@end
