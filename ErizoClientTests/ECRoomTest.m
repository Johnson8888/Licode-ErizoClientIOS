//
//  ECRoomTest.m
//  ErizoClientIOS
//
//  Created by Alvaro Gil on 5/24/17.
//
//

#import "ECUnitTest.h"
#import "ECRoom.h"
#import "ECClient.h"
#import "ECSignalingChannel.h"


@import WebRTC;

@interface ECRoomTest : ECUnitTest
@property ECStream *mockedStream;
@property ECRoom *room;
@property ECRoom *connectedRoom;
@property ECRoom *roomWithDelegate;
@property ECSignalingChannel *mockedSignalingChannel;
@property RTCPeerConnectionFactory *mockedPeerFactory;
@property id<ECRoomDelegate> mockedRoomDelegate;
@property ECStream *simpleStream;
@end

@implementation ECRoomTest

- (void)setUp {
    [super setUp];
    _mockedSignalingChannel = mock([ECSignalingChannel class]);
    _mockedRoomDelegate = mockProtocol(@protocol(ECRoomDelegate));
    _mockedPeerFactory = mock([RTCPeerConnectionFactory class]);
    _mockedStream = mock([ECStream class]);
    [given([_mockedStream streamId]) willReturn:@"123"];
    _room = [[ECRoom alloc] initWithDelegate:_mockedRoomDelegate
                              andPeerFactory:_mockedPeerFactory];
    _room.signalingChannel = _mockedSignalingChannel;
    _connectedRoom = [[ECRoom alloc] initWithDelegate:_mockedRoomDelegate
                                       andPeerFactory:nil];
    _connectedRoom.signalingChannel = _mockedSignalingChannel;
    [_connectedRoom signalingChannel:_mockedSignalingChannel
                    didConnectToRoom:@{
                                       @"id": @"roomId123",
                                       @"p2p": @"false",
                                       @"streams": @[]
                                       }];

    _simpleStream = [[ECStream alloc] initWithStreamId:@"123"
                                            attributes:@{}
                                      signalingChannel:_mockedSignalingChannel];
}

- (void)testReceiveRemoteStreamMustAssignSignalingChannelToStream {
    [_connectedRoom subscribe:_mockedStream];
    [_connectedRoom appClient:mock([ECClient class])
       didReceiveRemoteStream:mock([RTCMediaStream class])
            withStreamId:@"123"];
    [verify(_mockedStream) setSignalingChannel:_mockedSignalingChannel];
}

- (void)testRemoteStreamsPropertyReturnsRemoteStreamsOnly {
    [_room signalingChannel:nil didStreamAddedWithId:@"abc" event:nil];
    [_room signalingChannel:nil didStreamAddedWithId:@"def" event:nil];
    [_room signalingChannel:nil didReceiveStreamIdReadyToPublish:@"123"];
    XCTAssertEqual([[_room remoteStreams] count], 2);
    for (ECStream *stream in _room.remoteStreams) {
        XCTAssertNotEqual(stream.streamId, @"123");
    }
}

- (void)testCreateRoomCreatesPeerFactoryIfNil {
    ECRoom *room = [[ECRoom alloc] initWithDelegate:_mockedRoomDelegate
                                        andPeerFactory:nil];
    XCTAssert(room.peerFactory);
}

- (void)testRoomRelease {
    __weak ECRoom *weakReference;
    @autoreleasepool {
        ECRoom *reference = [[ECRoom alloc] initWithDelegate:_mockedRoomDelegate
                                              andPeerFactory:[[RTCPeerConnectionFactory alloc] init]];
        weakReference = reference;
        stopMocking(_mockedRoomDelegate);
    }
    XCTAssertNil(weakReference);
}

- (void)testRoomReleaseAfterLeave {
    __weak ECRoom *weakReference;
    @autoreleasepool {
        ECRoom *reference = [[ECRoom alloc] initWithDelegate:_mockedRoomDelegate
                                              andPeerFactory:[[RTCPeerConnectionFactory alloc] init]];
        weakReference = reference;
        [weakReference leave];
        stopMocking(_mockedRoomDelegate);
    }
    XCTAssertNil(weakReference);
}

# pragma mark - Subscribe

- (void)testSubscribeStreamWithoutStreamId {
    ECStream *stream = [[ECStream alloc] init];
    XCTAssertFalse([_room subscribe:stream]);
}

- (void)testSubscribeWithoutBeingConnected {
    XCTAssertNotEqual(_room.status, ECRoomStatusConnected);
    XCTAssertFalse([_room subscribe:_simpleStream]);
    XCTAssertEqual(_connectedRoom.status, ECRoomStatusConnected);
    XCTAssertTrue([_connectedRoom subscribe:_simpleStream]);
}

- (void)testSubscribeStreamMustKeepReferenceToStream {
    [_connectedRoom subscribe:_simpleStream];
    ECStream *roomStream = (ECStream *)[_connectedRoom.streamsByStreamId valueForKey:@"123"];
    XCTAssertNotNil(roomStream);
    XCTAssertEqual(_simpleStream, roomStream);
}

- (void)testSubscribeStreamMustStartSignaling {
    [_connectedRoom subscribe:_simpleStream];
    [verify(_mockedSignalingChannel) subscribe:@"123"
                                 streamOptions:_connectedRoom.defaultSubscribingStreamOptions
                      signalingChannelDelegate:anything()];
}

# pragma mark - Publish

- (void)testPublishSignalWithStreamOptions {
    __block BOOL callbackInvoked = NO;
    [givenVoid([_mockedSignalingChannel publish:anything()
                   signalingChannelDelegate:anything()]) willDo:^id (NSInvocation *invocation) {
        NSDictionary *options = [invocation mkt_arguments][0];
        assertThat(options, hasEntry(kStreamOptionAudio, @1));
        assertThat(options, hasEntry(kStreamOptionVideo, @1));
        assertThat(options, hasEntry(kStreamOptionData, @1));
        assertThat(options, hasKey(@"attributes"));
        callbackInvoked = YES;
        return nil;
    }];
    [_room publish:[[ECStream alloc] initLocalStream]];
    XCTAssertTrue(callbackInvoked);
}

# pragma mark - Unpublish

- (void)testUnpublishStream {
    [_room publish:_mockedStream];
    [_room signalingChannel:nil didReceiveStreamIdReadyToPublish:@"123"];
    [_room unpublish];
    [verify(_mockedSignalingChannel) unpublish:@"123"
                      signalingChannelDelegate:instanceOf([ECClient class])];
}

# pragma mark - Unsubscribe Stream

- (void)testUnsubscribeStreamSignalForUnsubscribe {
    [_room unsubscribe:_mockedStream];
    [verify(_mockedSignalingChannel) unsubscribe:_mockedStream.streamId];
}

# pragma mark - delegate ECRoomDelegate

- (void)testECRoomDelegateDidReceiveStreamIdReadyToPublish {
    [_room publish:_mockedStream];
    [_room signalingChannel:nil didReceiveStreamIdReadyToPublish:@"123"];
    XCTAssert(_room.publishStream);
}

- (void)testECRoomDelegateReceiveDidAddedStreamWhenSubscribing {
    [_connectedRoom subscribe:_mockedStream];
    [_connectedRoom signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    [verify(_mockedRoomDelegate) room:_connectedRoom didAddedStream:_mockedStream];
}
    
- (void)testECRoomDelegateReceiveDidPublishStream {
    [_room publish:_mockedStream];
    [_room signalingChannel:nil didReceiveStreamIdReadyToPublish:@"123"];
    [_room signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    [verify(_mockedRoomDelegate) room:_room didPublishStream:_mockedStream];
    [verifyCount(_mockedRoomDelegate, never()) room:_connectedRoom didAddedStream:anything()];
}

- (void)testECRoomDelegateReceiveDidUnpublishStream {
    [_room publish:_mockedStream];
    [_room signalingChannel:nil didReceiveStreamIdReadyToPublish:@"123"];
    [_room signalingChannel:nil didUnpublishStreamWithId:@"123"];
    [verify(_mockedRoomDelegate) room:_room didUnpublishStream:_mockedStream];
    XCTAssert(!_room.publishStream);
}


- (void)testCreateECStreamWhenReceiveNewStreamId {
    [_room signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    XCTAssertEqual([_room.remoteStreams count], 1);
}

# pragma mark - conform ECClientDelegate

- (void)testAppClientDidChangeStateChangeRoomStatus {
    XCTAssertEqual(_room.status, ECRoomStatusReady);
    [_room appClient:nil didChangeState:ECClientStateDisconnected];
    XCTAssertEqual(_room.status, ECRoomStatusDisconnected);
}

- (void)testAssignPeerFactoryAfterReceivingAnStream {
    [_connectedRoom subscribe:_mockedStream];
    [_connectedRoom appClient:nil didReceiveRemoteStream:nil
                                            withStreamId:_mockedStream.streamId];
    [verify(_mockedStream) setPeerFactory:_connectedRoom.peerFactory];
}

# pragma mark - conform ECSignalingChannel

- (void)testSignalingChannelDidConnectToRoomCreateAvailableStreamsWithAttributes {
    [_room signalingChannel:_mockedSignalingChannel
                    didConnectToRoom:@{
                                       @"id": @"roomId123",
                                       @"p2p": @"false",
                                       @"streams": @[@{
                                                        @"audio": @1,
                                                        @"video": @1,
                                                        @"id": @"abc",
                                                        @"attributes": @{@"name": @"john"}
                                                        },
                                                     @{
                                                        @"audio": @1,
                                                        @"video": @1,
                                                        @"id": @"def",
                                                        @"attributes": @{@"name": @"susan"}
                                                        }]
                                       }];
    XCTAssertEqual([_room.remoteStreams count], 2);
    NSString *john = [((ECStream *)[_room.remoteStreams objectAtIndex:0]).streamAttributes objectForKey:@"name"];
    NSString *susan = [((ECStream *)[_room.remoteStreams objectAtIndex:1]).streamAttributes objectForKey:@"name"];
    XCTAssertEqual(john, @"john");
    XCTAssertEqual(susan, @"susan");
}

- (void)testSignalingChannelDidRemovedStreamId {
    [_room signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    ECStream *stream = _room.remoteStreams[0];
    [_room signalingChannel:nil didRemovedStreamId:@"123"];
    [verify(_mockedRoomDelegate) room:_room didRemovedStream:stream];
    XCTAssertEqual([_room.remoteStreams count], 0);
}

- (void)testSignalingChannelDidUnsubscribeStream {
    [_room signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    ECStream *stream = _room.remoteStreams[0];
    [_room signalingChannel:nil didUnsubscribeStreamWithId:@"123"];
    [verify(_mockedRoomDelegate) room:_room didUnSubscribeStream:stream];
    XCTAssertEqual([_room.remoteStreams count], 1);
}

- (void)testSignalingChannelDidStartRecording {
    NSDate *date = [NSDate date];
    [_connectedRoom publish:_mockedStream];
    [_connectedRoom signalingChannel:nil didStartRecordingStreamId:_mockedStream.streamId withRecordingId:@"456" recordingDate:date];
    [verify(_mockedRoomDelegate) room:_connectedRoom didStartRecordingStream:_mockedStream withRecordingId:@"456" recordingDate:date];
}

- (void)testSignalingChannelUpdateStreamAttributes {
    [_room signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    ECStream *stream = ((ECStream *)_room.remoteStreams[0]);
    [_room signalingChannel:nil fromStreamId:@"123" updateStreamAttributes:@{@"name": @"john"}];
    NSDictionary *streamAttributes = stream.streamAttributes;
    XCTAssertEqual([streamAttributes objectForKey:@"name"],@"john");
    [verify(_mockedRoomDelegate) room:_room didUpdateAttributesOfStream:stream];
}

- (void)testSignalingChannelDidUnsubscribeStreamWithId {
    [_room signalingChannel:nil didStreamAddedWithId:@"123" event:nil];
    [_room signalingChannel:_mockedSignalingChannel didUnsubscribeStreamWithId:@"123"];
    [verify(_mockedRoomDelegate) room:_room didUnSubscribeStream:_room.remoteStreams[0]];
}

@end
