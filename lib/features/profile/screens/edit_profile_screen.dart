// lib/features/profile/screens/edit_profile_screen.dart
//
// プロフィール編集画面
// アバター画像・表示名・ユーザー名・自己紹介を更新する。

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';
import 'package:yu_map/domain/entities/user.dart' as app;
import 'package:yu_map/providers/auth_provider.dart';

/// プロフィール編集画面
///
/// users テーブルの avatar_url / display_name / username / bio を更新する。
/// 更新後は [currentUserProfileProvider] を invalidate して
/// プロフィール画面が最新情報を再表示できるようにする。
class EditProfileScreen extends ConsumerStatefulWidget {
  const EditProfileScreen({super.key, required this.user});

  final app.User user;

  @override
  ConsumerState<EditProfileScreen> createState() => _EditProfileScreenState();
}

class _EditProfileScreenState extends ConsumerState<EditProfileScreen> {
  final _formKey = GlobalKey<FormState>();
  final _imagePicker = ImagePicker();

  late final TextEditingController _displayNameController;
  late final TextEditingController _usernameController;
  late final TextEditingController _bioController;

  /// ユーザーが新たに選択したアバター画像（null = 変更なし）
  XFile? _pickedAvatar;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _displayNameController =
        TextEditingController(text: widget.user.displayName ?? '');
    _usernameController =
        TextEditingController(text: widget.user.username ?? '');
    _bioController = TextEditingController(text: widget.user.bio ?? '');
  }

  @override
  void dispose() {
    _displayNameController.dispose();
    _usernameController.dispose();
    _bioController.dispose();
    super.dispose();
  }

  // ── 画像選択 ──────────────────────────────────────────────────────────────

  Future<void> _pickAvatar() async {
    final picked = await _imagePicker.pickImage(
      source: ImageSource.gallery,
      maxWidth: 512,
      maxHeight: 512,
      imageQuality: 85,
    );
    if (picked != null) {
      setState(() => _pickedAvatar = picked);
    }
  }

  /// アバターをStorageにアップロードしてURLを返す
  ///
  /// 既存画像を上書きするため upsert: true を使用する。
  /// パス: avatars/{userId}/avatar.{ext}
  Future<String> _uploadAvatar(SupabaseClient client, String userId) async {
    final rawExt = _pickedAvatar!.path.split('.').last.toLowerCase();
    final safeExt =
        ['jpg', 'jpeg', 'png', 'webp'].contains(rawExt) ? rawExt : 'jpg';

    // ファイル名にUUIDを付けてブラウザキャッシュを強制更新させる
    final fileName = '${const Uuid().v4()}.$safeExt';
    final storagePath = '$userId/$fileName';
    final bytes = await _pickedAvatar!.readAsBytes();

    await client.storage.from('avatars').uploadBinary(
          storagePath,
          bytes,
          fileOptions: FileOptions(
            contentType: 'image/$safeExt',
            upsert: true,
          ),
        );

    return client.storage.from('avatars').getPublicUrl(storagePath);
  }

  // ── Validation ────────────────────────────────────────────────────────────

  String? _validateDisplayName(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return '表示名を入力してください';
    if (trimmed.length > 50) return '50文字以内で入力してください';
    return null;
  }

  String? _validateUsername(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) return null;
    if (trimmed.length > 30) return '30文字以内で入力してください';
    final usernameRegex = RegExp(r'^[a-zA-Z0-9_]+$');
    if (!usernameRegex.hasMatch(trimmed)) {
      return '英数字とアンダースコアのみ使用できます';
    }
    return null;
  }

  String? _validateBio(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.length > 200) return '200文字以内で入力してください';
    return null;
  }

  // ── Save ─────────────────────────────────────────────────────────────────

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final client = ref.read(supabaseClientProvider);
    final session = ref.read(sessionProvider);
    if (client == null || session == null) {
      _showError('データベースに接続できません');
      return;
    }

    setState(() => _saving = true);

    try {
      // 新しい画像が選択されていればアップロードしてURLを取得
      String? newAvatarUrl;
      if (_pickedAvatar != null) {
        newAvatarUrl = await _uploadAvatar(client, session.user.id);
      }

      final displayName = _displayNameController.text.trim();
      final username = _usernameController.text.trim();
      final bio = _bioController.text.trim();

      await client.from('users').update({
        'display_name': displayName.isEmpty ? null : displayName,
        'username': username.isEmpty ? null : username,
        'bio': bio.isEmpty ? null : bio,
        // 画像が新たに選択された場合のみ avatar_url を更新
        if (newAvatarUrl != null) 'avatar_url': newAvatarUrl,
      }).eq('id', widget.user.id);

      // キャッシュを破棄して画面を更新
      ref.invalidate(currentUserProfileProvider);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('プロフィールを更新しました')),
      );
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      // PostgreSQLの一意制約違反（エラーコード23505）はユーザー名重複
      final errorStr = e.toString();
      if (errorStr.contains('23505') ||
          errorStr.contains('unique') ||
          errorStr.contains('duplicate')) {
        _showError('このユーザー名はすでに使われています。別のユーザー名をお試しください。');
      } else {
        _showError('更新に失敗しました。もう一度お試しください。');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('プロフィール編集'),
        actions: [
          TextButton(
            onPressed: _saving ? null : _save,
            child: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('保存'),
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            // ── アバター画像 ───────────────────────────────────────────
            Center(
              child: _AvatarPicker(
                currentAvatarUrl: widget.user.avatarUrl,
                pickedImage: _pickedAvatar,
                onTap: _saving ? null : _pickAvatar,
              ),
            ),
            const SizedBox(height: 28),

            // ── Display name ───────────────────────────────────────────
            TextFormField(
              controller: _displayNameController,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              maxLength: 50,
              decoration: const InputDecoration(
                labelText: '表示名',
                hintText: '湯めぐりハナコ',
                helperText: 'アプリ上で表示される名前です',
              ),
              validator: _validateDisplayName,
            ),
            const SizedBox(height: 16),

            // ── Username ───────────────────────────────────────────────
            TextFormField(
              controller: _usernameController,
              textInputAction: TextInputAction.next,
              enabled: !_saving,
              maxLength: 30,
              decoration: const InputDecoration(
                labelText: 'ユーザー名（任意）',
                hintText: 'onsen_hanako',
                helperText: '英数字とアンダースコアのみ使用可',
              ),
              validator: _validateUsername,
            ),
            const SizedBox(height: 16),

            // ── Bio ────────────────────────────────────────────────────
            TextFormField(
              controller: _bioController,
              textInputAction: TextInputAction.done,
              enabled: !_saving,
              maxLines: 4,
              maxLength: 200,
              decoration: const InputDecoration(
                labelText: '自己紹介（任意）',
                hintText: '温泉好きです。全国の秘湯を巡るのが趣味。',
                alignLabelWithHint: true,
              ),
              validator: _validateBio,
            ),
          ],
        ),
      ),
    );
  }
}

// ── アバター選択ウィジェット ───────────────────────────────────────────────────

class _AvatarPicker extends StatelessWidget {
  const _AvatarPicker({
    required this.currentAvatarUrl,
    required this.pickedImage,
    required this.onTap,
  });

  final String? currentAvatarUrl;
  final XFile? pickedImage;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Stack(
        alignment: Alignment.bottomRight,
        children: [
          // ── アバター本体 ─────────────────────────────────────────────
          _buildAvatar(context),

          // ── 右下の編集バッジ ─────────────────────────────────────────
          Container(
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.primary,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).scaffoldBackgroundColor,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.camera_alt,
              size: 16,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAvatar(BuildContext context) {
    const radius = 52.0;

    // 新たに選択したローカル画像を優先表示
    if (pickedImage != null) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: FileImage(File(pickedImage!.path)),
        backgroundColor: const Color(0xFFE3F2FD),
      );
    }

    // 既存のアバターURL（ネットワーク画像）
    // onBackgroundImageError が発生した場合は child のアイコンを表示する
    if (currentAvatarUrl != null && currentAvatarUrl!.isNotEmpty) {
      return CircleAvatar(
        radius: radius,
        backgroundImage: NetworkImage(currentAvatarUrl!),
        backgroundColor: const Color(0xFFE3F2FD),
        onBackgroundImageError: (_, __) {
          // 画像ロード失敗時は child（デフォルトアイコン）が表示される
        },
        child: Icon(
          Icons.person,
          size: radius,
          color: const Color(0xFF1565C0),
        ),
      );
    }

    // 未設定のデフォルトアバター
    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE3F2FD),
      child: Icon(
        Icons.person,
        size: radius,
        color: Theme.of(context).colorScheme.primary,
      ),
    );
  }
}
