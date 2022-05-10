
#import "RNGooglePlaces.h"
#import "NSMutableDictionary+GMSPlace.h"
#import <React/RCTBridge.h>
#import "RCTConvert+RNGPAutocompleteTypeFilter.h"
#import <React/RCTRootView.h>
#import <React/RCTLog.h>
#import <React/RCTConvert.h>

#import <GooglePlaces/GooglePlaces.h>
#import <GoogleMapsBase/GoogleMapsBase.h>
#import <MapKit/MapKit.h>


@implementation RNGooglePlaces

RNGooglePlaces *_instance;

RCT_EXPORT_MODULE()

- (dispatch_queue_t)methodQueue
{
    return dispatch_get_main_queue();
}

+ (BOOL)requiresMainQueueSetup
{
    return YES;
}

- (instancetype)init
{
    if (self = [super init]) {
        _instance = self;
    }
    
    return self;
}

RCT_EXPORT_METHOD(getAutocompletePredictions: (NSString *)query
                  filterOptions: (NSDictionary *)options
                  resolver: (RCTPromiseResolveBlock)resolve
                  rejecter: (RCTPromiseRejectBlock)reject)
{
    NSMutableArray *autoCompleteSuggestionsList = [NSMutableArray array];
    GMSAutocompleteFilter *autocompleteFilter = [[GMSAutocompleteFilter alloc] init];
    autocompleteFilter.type = [self getFilterType:[RCTConvert NSString:options[@"type"]]];
    autocompleteFilter.country = [options[@"country"] length] == 0? nil : options[@"country"];
    
    NSDictionary *locationBias = [RCTConvert NSDictionary:options[@"locationBias"]];
    NSDictionary *locationRestriction = [RCTConvert NSDictionary:options[@"locationRestriction"]];

    NSDictionary *location = [RCTConvert NSDictionary:options[@"location"]];
    NSNumber *locationRadius = [RCTConvert NSNumber:options[@"radius"]];

    
    GMSCoordinateBounds *autocompleteBounds = [self getBounds:locationBias andRestrictOptions:locationRestriction andLocation:location radiusMeters:locationRadius];
    
    autocompleteFilter.locationBias = GMSPlaceRectangularLocationOption(autocompleteBounds.northEast, autocompleteBounds.southWest);
    autocompleteFilter.locationRestriction = GMSPlaceRectangularLocationOption(autocompleteBounds.northEast, autocompleteBounds.southWest);
    
    GMSAutocompleteSessionToken *token = [[GMSAutocompleteSessionToken alloc] init];
    
    [[GMSPlacesClient sharedClient] findAutocompletePredictionsFromQuery:query
                                                                  filter:autocompleteFilter
                                                            sessionToken:token
                                                                callback:^(NSArray<GMSAutocompletePrediction *> * _Nullable results, NSError *error) {
        if (error != nil) {
            reject(@"E_AUTOCOMPLETE_ERROR", [error description], nil);
            return;
        }
        
        if (results != nil) {
            for (GMSAutocompletePrediction* result in results) {
                NSMutableDictionary *placeData = [[NSMutableDictionary alloc] init];
                
                placeData[@"fullText"] = result.attributedFullText.string;
                placeData[@"primaryText"] = result.attributedPrimaryText.string;
                placeData[@"secondaryText"] = result.attributedSecondaryText.string;
                placeData[@"placeID"] = result.placeID;
                placeData[@"types"] = result.types;
                
                [autoCompleteSuggestionsList addObject:placeData];
            }
            
            resolve(autoCompleteSuggestionsList);
            
        }
        
    }];
}

RCT_EXPORT_METHOD(lookUpPlaceByID: (NSString*)placeID
                 withFields: (NSArray *)fields
                 resolver: (RCTPromiseResolveBlock)resolve
                 rejecter: (RCTPromiseRejectBlock)reject)
{
    GMSPlaceField selectedFields = [self getSelectedFields:fields isCurrentOrFetchPlace:false];

    [[GMSPlacesClient sharedClient] fetchPlaceFromPlaceID:placeID placeFields:selectedFields sessionToken:nil
                                         callback:^(GMSPlace * _Nullable place, NSError * _Nullable error) {
                                             if (error != nil) {
                                                 reject(@"E_PLACE_DETAILS_ERROR", [error localizedDescription], nil);
                                                 return;
                                             }
                                             
                                             if (place != nil) {
                                                 resolve([NSMutableDictionary dictionaryWithGMSPlace:place]);
                                             } else {
                                                 resolve(@{});
                                             }
                                         }];
}

- (NSError *) errorFromException: (NSException *) exception
{
    NSDictionary *exceptionInfo = @{
                                    @"name": exception.name,
                                    @"reason": exception.reason,
                                    @"callStackReturnAddresses": exception.callStackReturnAddresses,
                                    @"callStackSymbols": exception.callStackSymbols,
                                    @"userInfo": exception.userInfo
                                    };
    
    return [[NSError alloc] initWithDomain: @"RNGooglePlaces"
                                      code: 0
                                  userInfo: exceptionInfo];
}

- (GMSPlacesAutocompleteTypeFilter) getFilterType:(NSString *)type
{
    if ([type isEqualToString: @"regions"]) {
        return kGMSPlacesAutocompleteTypeFilterRegion;
    } else if ([type isEqualToString: @"geocode"]) {
        return kGMSPlacesAutocompleteTypeFilterGeocode;
    } else if ([type isEqualToString: @"address"]) {
        return kGMSPlacesAutocompleteTypeFilterAddress;
    } else if ([type isEqualToString: @"establishment"]) {
        return kGMSPlacesAutocompleteTypeFilterEstablishment;
    } else if ([type isEqualToString: @"cities"]) {
        return kGMSPlacesAutocompleteTypeFilterCity;
    } else {
        return kGMSPlacesAutocompleteTypeFilterNoFilter;
    }
}

- (GMSPlaceField) getSelectedFields:(NSArray *)fields isCurrentOrFetchPlace:(Boolean)currentOrFetch
{
    NSDictionary *fieldsMapping = @{
        @"name" : @(GMSPlaceFieldName),
        @"placeID" : @(GMSPlaceFieldPlaceID),
        @"plusCode" : @(GMSPlaceFieldPlusCode),
        @"location" : @(GMSPlaceFieldCoordinate),
        @"openingHours" : @(GMSPlaceFieldOpeningHours),
        @"phoneNumber" : @(GMSPlaceFieldPhoneNumber),
        @"address" : @(GMSPlaceFieldFormattedAddress),
        @"rating" : @(GMSPlaceFieldRating),
        @"userRatingsTotal" : @(GMSPlaceFieldUserRatingsTotal),
        @"priceLevel" : @(GMSPlaceFieldPriceLevel),
        @"types" : @(GMSPlaceFieldTypes),
        @"website" : @(GMSPlaceFieldWebsite),
        @"viewport" : @(GMSPlaceFieldViewport),
        @"addressComponents" : @(GMSPlaceFieldAddressComponents),
        @"photos" : @(GMSPlaceFieldPhotos),
    };
    
    if ([fields count] == 0 && !currentOrFetch) {
        return GMSPlaceFieldAll;
    }

    if ([fields count] == 0 && currentOrFetch) {
        GMSPlaceField placeFields = 0;
        for (NSString *fieldLabel in fieldsMapping) {
            if ([fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldOpeningHours &&
                [fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldPhoneNumber &&
                [fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldWebsite &&
                [fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldAddressComponents) {
                placeFields |= [fieldsMapping[fieldLabel] integerValue];
            }
        }
        return placeFields;
    }

    if ([fields count] != 0 && currentOrFetch) {
        GMSPlaceField placeFields = 0;
        for (NSString *fieldLabel in fields) {
            if ([fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldOpeningHours &&
                [fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldPhoneNumber &&
                [fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldWebsite &&
                [fieldsMapping[fieldLabel] integerValue] != GMSPlaceFieldAddressComponents) {
                placeFields |= [fieldsMapping[fieldLabel] integerValue];
            }
        }
        return placeFields;
    }

    if ([fields count] != 0 && !currentOrFetch) {
        GMSPlaceField placeFields = 0;
        for (NSString *fieldLabel in fields) {
            placeFields |= [fieldsMapping[fieldLabel] integerValue];
        }
        return placeFields;
    }
    
    return GMSPlaceFieldAll;
}

- (GMSCoordinateBounds *) getBounds: (NSDictionary *)biasOptions andRestrictOptions: (NSDictionary *)restrictOptions andLocation:(NSDictionary *)location radiusMeters:(NSNumber *)radius
{
    double biasLatitudeSW = [[RCTConvert NSNumber:biasOptions[@"latitudeSW"]] doubleValue];
    double biasLongitudeSW = [[RCTConvert NSNumber:biasOptions[@"longitudeSW"]] doubleValue];
    double biasLatitudeNE = [[RCTConvert NSNumber:biasOptions[@"latitudeNE"]] doubleValue];
    double biasLongitudeNE = [[RCTConvert NSNumber:biasOptions[@"longitudeNE"]] doubleValue];

    double restrictLatitudeSW = [[RCTConvert NSNumber:restrictOptions[@"latitudeSW"]] doubleValue];
    double restrictLongitudeSW = [[RCTConvert NSNumber:restrictOptions[@"longitudeSW"]] doubleValue];
    double restrictLatitudeNE = [[RCTConvert NSNumber:restrictOptions[@"latitudeNE"]] doubleValue];
    double restrictLongitudeNE = [[RCTConvert NSNumber:restrictOptions[@"longitudeNE"]] doubleValue];

    double locationLongitude = [[RCTConvert NSNumber:location[@"longitude"]] doubleValue];
    double locationLatitude = [[RCTConvert NSNumber:location[@"latitude"]] doubleValue];

    double locationRadius = [[RCTConvert NSNumber:location[@"radius"]] doubleValue];

    if (biasLatitudeSW != 0 && biasLongitudeSW != 0 && biasLatitudeNE != 0 && biasLongitudeNE != 0) {
        CLLocationCoordinate2D neBoundsCorner = CLLocationCoordinate2DMake(biasLatitudeNE, biasLongitudeNE);
        CLLocationCoordinate2D swBoundsCorner = CLLocationCoordinate2DMake(biasLatitudeSW, biasLongitudeSW);
        GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:neBoundsCorner
                                                                        coordinate:swBoundsCorner];

        return bounds;
    }  

    if (restrictLatitudeSW != 0 && restrictLongitudeSW != 0 && restrictLatitudeNE != 0 && restrictLongitudeNE != 0) {
        CLLocationCoordinate2D neBoundsCorner = CLLocationCoordinate2DMake(restrictLatitudeNE, restrictLongitudeNE);
        CLLocationCoordinate2D swBoundsCorner = CLLocationCoordinate2DMake(restrictLatitudeSW, restrictLongitudeSW);
        GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:neBoundsCorner
                                                                        coordinate:swBoundsCorner];
        
        return bounds;
    }
    
    if (locationLongitude != 0 && locationLatitude != 0 && locationRadius != 0) {
        MKCoordinateRegion region = MKCoordinateRegionMakeWithDistance(CLLocationCoordinate2DMake(locationLatitude, locationLongitude), locationRadius, locationRadius);
        CLLocationCoordinate2D northWest = CLLocationCoordinate2DMake(region.center.latitude + region.span.latitudeDelta / 2, region.center.longitude - region.span.longitudeDelta / 2);
        CLLocationCoordinate2D southEast = CLLocationCoordinate2DMake(region.center.latitude - region.span.latitudeDelta / 2, region.center.longitude + region.span.longitudeDelta / 2);
        GMSCoordinateBounds *bounds = [[GMSCoordinateBounds alloc] initWithCoordinate:northWest
                                                                           coordinate:southEast];
        
        return bounds;
    }
    
    return nil;
}


@end

