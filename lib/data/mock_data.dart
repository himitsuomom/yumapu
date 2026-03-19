import 'package:yu_map/models/facility.dart';
import 'package:yu_map/models/post.dart';
import 'package:yu_map/models/user.dart';

// Mock Facilities
final List<Facility> mockFacilities = [
  Facility(
    id: '1',
    name: '新宿 天然温泉 テルマー湯',
    type: 'supersento',
    price: 2600,
    rating: 4.5,
    reviewCount: 1280,
    isOpen: true,
    address: '東京都新宿区歌舞伎町1-1-2',
    phone: '03-1234-5678',
    hours: '24時間営業',
    holiday: '年中無休',
    x: 0.4,
    y: 0.3,
    amenities: {
      'tattooFriendly': false,
      'restaurant': true,
      'naturalHotSpring': true
    },
  ),
  Facility(
    id: '2',
    name: 'サウナセンター 渋谷',
    type: 'sauna',
    price: 1800,
    rating: 4.8,
    reviewCount: 850,
    isOpen: true,
    address: '東京都渋谷区道玄坂2-X-X',
    phone: '03-9876-5432',
    hours: '10:00 - 翌5:00',
    holiday: '不定休',
    x: 0.6,
    y: 0.6,
    amenities: {
      'tattooFriendly': true,
      'restaurant': true,
      'naturalHotSpring': false
    },
  ),
];

// Mock Comments
final mockComments = [
  Comment(
    id: 'c1',
    user: 'サウナマン',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=sauna',
    text: 'いいですね！',
    time: '10時間前',
  )
];

// Mock Posts
final List<Post> mockPosts = [
  Post(
    id: '0',
    user: 'ゲストユーザー',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=user123',
    content: '今日は近所のサウナへ。しっかり3セットこなして最高にととのいました！',
    time: '1日前',
    likes: 12,
    isLiked: false,
    facilityId: '2',
    facilityName: 'サウナセンター 渋谷',
    imageUrl:
        'https://images.unsplash.com/photo-1515362665818-472b535d5d85?q=80&w=800&auto=format&fit=crop',
    comments: mockComments,
  ),
];

// Mock Users
final mockUsers = [
  UserProfile(
    name: 'サウナマン',
    handle: '@saunaman',
    bio: 'サウナ好きです',
    avatar: 'https://api.dicebear.com/7.x/avataaars/svg?seed=sauna',
  ),
];
