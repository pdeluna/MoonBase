import 'package:flutter_test/flutter_test.dart';
import 'package:moonbase_skeleton/models/models.dart';

void main() {
  group('Enum Tests', () {
    group('BaseRole', () {
      test('should have correct values', () {
        expect(BaseRole.owner.name, 'owner');
        expect(BaseRole.admin.name, 'admin');
        expect(BaseRole.member.name, 'member');
      });

      test('should be able to get enum by name', () {
        expect(BaseRole.values.byName('owner'), BaseRole.owner);
        expect(BaseRole.values.byName('admin'), BaseRole.admin);
        expect(BaseRole.values.byName('member'), BaseRole.member);
      });

      test('should throw error for invalid name', () {
        expect(() => BaseRole.values.byName('invalid'), throwsA(isA<ArgumentError>()));
      });
    });

    group('LiveStatus', () {
      test('should have correct values', () {
        expect(LiveStatus.scheduled.name, 'scheduled');
        expect(LiveStatus.live.name, 'live');
        expect(LiveStatus.ended.name, 'ended');
      });

      test('should be able to get enum by name', () {
        expect(LiveStatus.values.byName('scheduled'), LiveStatus.scheduled);
        expect(LiveStatus.values.byName('live'), LiveStatus.live);
        expect(LiveStatus.values.byName('ended'), LiveStatus.ended);
      });
    });

    group('MediaType', () {
      test('should have correct values', () {
        expect(MediaType.image.name, 'image');
        expect(MediaType.video.name, 'video');
        expect(MediaType.link.name, 'link');
      });

      test('should be able to get enum by name', () {
        expect(MediaType.values.byName('image'), MediaType.image);
        expect(MediaType.values.byName('video'), MediaType.video);
        expect(MediaType.values.byName('link'), MediaType.link);
      });
    });

    group('MessageType', () {
      test('should have correct values', () {
        expect(MessageType.text.name, 'text');
        expect(MessageType.media.name, 'media');
        expect(MessageType.system.name, 'system');
      });

      test('should be able to get enum by name', () {
        expect(MessageType.values.byName('text'), MessageType.text);
        expect(MessageType.values.byName('media'), MessageType.media);
        expect(MessageType.values.byName('system'), MessageType.system);
      });
    });
  });
}
