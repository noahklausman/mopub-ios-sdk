#import "MPAdView.h"
#import "MPAdConfigurationFactory.h"
#import "FakeGADBannerView.h"

using namespace Cedar::Matchers;
using namespace Cedar::Doubles;

SPEC_BEGIN(MPGoogleAdMobBannerIntegrationSuite)

describe(@"MPGoogleAdMobBannerIntegrationSuite", ^{
    __block FakeGADBannerView *fakeAd;
    __block GADRequest<CedarDouble> *fakeGADRequest;
    __block MPAdConfiguration *configuration;

    __block MPAdView *banner;
    __block id<CedarDouble, MPAdViewDelegate> delegate;
    __block UIViewController *presentingController;
    __block FakeMPAdServerCommunicator *communicator;

    beforeEach(^{
        presentingController = [[[UIViewController alloc] init] autorelease];
        delegate = nice_fake_for(@protocol(MPAdViewDelegate));
        delegate stub_method(@selector(viewControllerForPresentingModalView)).and_return(presentingController);

        banner = [[[MPAdView alloc] initWithAdUnitId:@"admob_event" size:MOPUB_BANNER_SIZE] autorelease];
        banner.delegate = delegate;
        banner.location = [[[CLLocation alloc] initWithCoordinate:CLLocationCoordinate2DMake(37.1, 21.2)
                                                         altitude:11
                                               horizontalAccuracy:12.3
                                                 verticalAccuracy:10
                                                        timestamp:[NSDate date]] autorelease];
        [banner loadAd];

        fakeAd = [[[FakeGADBannerView alloc] initWithFrame:CGRectMake(0,0,20,30)] autorelease];
        fakeProvider.fakeGADBannerView = fakeAd.masquerade;
        fakeGADRequest = nice_fake_for([GADRequest class]);
        fakeProvider.fakeGADRequest = fakeGADRequest;

        NSDictionary *headers = @{kAdTypeHeaderKey: @"admob_native",
                                  kNativeSDKParametersHeaderKey:@"{\"adUnitID\":\"g00g1e\",\"adWidth\":728,\"adHeight\":90}"};
        configuration = [MPAdConfigurationFactory defaultBannerConfigurationWithHeaders:headers
                                                                             HTMLString:nil];

        communicator = fakeProvider.lastFakeMPAdServerCommunicator;
        [communicator receiveConfiguration:configuration];
    });

    it(@"should ask the ad to load", ^{
        fakeAd.adUnitID should equal(@"g00g1e");
        fakeGADRequest should have_received(@selector(setLocationWithLatitude:longitude:accuracy:)).with(37.1f).and_with(21.2f).and_with(12.3f);
        fakeAd.rootViewController should equal(presentingController);
    });

    context(@"when the ad loads succesfully", ^{
        beforeEach(^{
            [delegate reset_sent_messages];
            [fakeAd simulateLoadingAd];
        });

        it(@"should tell the delegate, show the ad, and track an impression", ^{
            verify_fake_received_selectors(delegate, @[@"adViewDidLoadAd:"]);
            banner.subviews should equal(@[fakeAd]);
            banner.adContentViewSize should equal(CGSizeMake(728, 90));
            fakeProvider.sharedFakeMPAnalyticsTracker.trackedImpressionConfigurations should equal(@[configuration]);
        });

        context(@"when the user taps the ad", ^{
            beforeEach(^{
                [delegate reset_sent_messages];
                [fakeAd simulateUserTap];
            });

            it(@"should tell the delegate and track a click (just once)", ^{
                verify_fake_received_selectors(delegate, @[@"willPresentModalViewForAd:"]);
                fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should equal(@[configuration]);

                [fakeAd simulateUserTap];
                fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should equal(@[configuration]);
            });

            context(@"when the user dismisses the modal", ^{
                beforeEach(^{
                    [delegate reset_sent_messages];
                    [fakeAd simulateUserEndingInteraction];
                });

                it(@"should tell the delegate", ^{
                    verify_fake_received_selectors(delegate, @[@"didDismissModalViewForAd:"]);
                });
            });

            context(@"when the user leaves the application", ^{
                beforeEach(^{
                    [delegate reset_sent_messages];
                    [fakeAd simulateUserLeavingApplication];
                });

                it(@"should tell the delegate", ^{
                    verify_fake_received_selectors(delegate, @[@"willLeaveApplicationFromAd:"]);
                });
            });
        });

        context(@"when the user leaves the application", ^{
            beforeEach(^{
                [delegate reset_sent_messages];
                [fakeAd simulateUserLeavingApplication];
            });

            it(@"should tell the delegate and track a click (just once)", ^{
                verify_fake_received_selectors(delegate, @[@"willLeaveApplicationFromAd:"]);
                fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should equal(@[configuration]);

                [fakeAd simulateUserLeavingApplication];
                fakeProvider.sharedFakeMPAnalyticsTracker.trackedClickConfigurations should equal(@[configuration]);
            });
        });
    });

    context(@"when the ad fails to load", ^{
        beforeEach(^{
            [fakeAd simulateFailingToLoad];
        });

        it(@"should start the waterfall", ^{
            communicator.loadedURL should equal(configuration.failoverURL);
        });
    });
});

SPEC_END
