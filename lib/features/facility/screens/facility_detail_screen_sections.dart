part of 'facility_detail_screen.dart';

// ── _FacilityDetailScreenState の大型 build メソッドを部分ファイルへ移動 ──────
//
// Dart の part 構造を利用することで private なフィールド・メソッドへのアクセスを
// 維持しつつ、主ファイルの行数を削減する。

extension _FacilityDetailStateUI on _FacilityDetailScreenState {
  // ── チェックイン「近日公開」バー ──────────────────────────────────────────

  Widget _buildCheckinComingSoonBar() {
    return SafeArea(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          border: Border(
            top: BorderSide(
              color: Theme.of(context).dividerColor.withValues(alpha: 0.5),
            ),
          ),
        ),
        child: SizedBox(
          height: 48,
          width: double.infinity,
          child: OutlinedButton.icon(
            icon: Icon(
              Icons.hourglass_empty_outlined,
              size: 18,
              color: Theme.of(context).colorScheme.outline,
            ),
            label: Text(
              'チェックイン（近日公開）',
              style: TextStyle(
                color: Theme.of(context).colorScheme.outline,
              ),
            ),
            style: OutlinedButton.styleFrom(
              side: BorderSide(
                color: Theme.of(context)
                    .colorScheme
                    .outline
                    .withValues(alpha: 0.4),
              ),
            ),
            onPressed: null,
          ),
        ),
      ),
    );
  }

  // ── Scaffold 本体 ─────────────────────────────────────────────────────────

  Widget _buildScaffold(Facility facility) {
    final isSignedIn = ref.watch(isSignedInProvider);
    final isGuestMode = ref.watch(guestModeProvider);
    final isFavorite = ref.watch(isFavoriteProvider(facility.id));
    final likedIds = isSignedIn
        ? ref.watch(likedReviewIdsProvider(facility.id)).valueOrNull ?? {}
        : <String>{};
    final currentUserId = ref.watch(sessionProvider)?.user.id;
    final photos =
        ref.watch(facilityPhotosProvider(facility.id)).valueOrNull ?? [];

    return Scaffold(
      bottomNavigationBar:
          AppConfig.isCheckinEnabled && (isSignedIn || isGuestMode)
              ? _StickyCheckinBar(
                  facility: facility,
                  isSignedIn: isSignedIn,
                  isCheckingIn: _isCheckingIn,
                  onCheckin: () => _showCheckinDialog(facility),
                )
              : !AppConfig.isCheckinEnabled
                  ? _buildCheckinComingSoonBar()
                  : null,
      body: CustomScrollView(
        controller: _scrollController,
        slivers: [
          SliverAppBar(
            expandedHeight: 250,
            pinned: true,
            flexibleSpace: FlexibleSpaceBar(
              titlePadding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              title: Text(
                facility.name,
                style: const TextStyle(
                  fontSize: 14,
                  shadows: [Shadow(blurRadius: 4, color: Colors.black54)],
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              background: _FacilityHeaderBackground(
                photos: photos,
                controller: _headerPageController,
                currentIndex: _headerPhotoIndex,
                onPageChanged: _onHeaderPageChanged,
                facility: facility,
              ),
            ),
            actions: [
              IconButton(
                tooltip: 'シェア',
                icon: const Icon(Icons.share_outlined, color: Colors.white),
                onPressed: () => _shareFacility(facility),
              ),
              if (isSignedIn)
                IconButton(
                  tooltip: isFavorite ? 'お気に入りを解除' : 'お気に入りに追加',
                  icon: Icon(
                    isFavorite ? Icons.favorite : Icons.favorite_border,
                    color: isFavorite ? Colors.red : Colors.white,
                  ),
                  onPressed: () =>
                      ref.read(favoritesProvider.notifier).toggle(facility.id),
                ),
            ],
          ),

          SliverToBoxAdapter(
            child: FacilityRatingBar(facilityId: facility.id),
          ),

          SliverToBoxAdapter(
            child: FacilityInfoSection(
              facility: facility,
              onPhone: facility.phone != null
                  ? () => _launchPhone(facility.phone!)
                  : null,
              onWebsite: facility.website != null
                  ? () => _launchUrl(facility.website!)
                  : null,
              onGoToMap: facility.hasValidLocation
                  ? () => _goToMapTab(facility)
                  : null,
            ),
          ),

          if (isSignedIn)
            SliverToBoxAdapter(
              child: _FacilityActionButtons(
                onReview: AppConfig.isReviewEnabled
                    ? () => _showReviewSheet(facility)
                    : null,
                onPlan: () => _showAddToPlanSheet(facility),
              ),
            ),

          SliverToBoxAdapter(
            child: FacilityAmenitySection(facilityId: facility.id),
          ),

          SliverToBoxAdapter(
            child: _OwnerEditButton(
              facilityId: facility.id,
              onEdit: () => _openOwnerFacilityEdit(facility),
            ),
          ),

          SliverToBoxAdapter(
            child: _FacilityImproveSection(
              onReport: () => _openFacilityReport(facility),
              onOwner: () => _openOwnerRegistration(facility),
            ),
          ),

          if (AppConfig.isReviewEnabled)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.fromLTRB(16, 16, 16, 0),
                child: Text(
                  'レビュー',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ),

          if (AppConfig.isReviewEnabled && _reviewInitialLoading)
            const SliverToBoxAdapter(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
            )
          else if (AppConfig.isReviewEnabled && _reviewError != null)
            SliverToBoxAdapter(
              child: AppErrorWidget(
                message: _reviewError!,
                onRetry: _loadReviews,
              ),
            )
          else if (AppConfig.isReviewEnabled && _reviews.isEmpty)
            SliverToBoxAdapter(
              child: _EmptyReviewView(
                isSignedIn: isSignedIn,
                onWrite: () => _showReviewSheet(facility),
                onLogin: () => Navigator.of(context).pushNamed('/login'),
              ),
            )
          else if (AppConfig.isReviewEnabled)
            SliverList(
              delegate: SliverChildBuilderDelegate(
                (_, i) {
                  final reviewId = _reviews[i].id;
                  final alreadyLiked = likedIds.contains(reviewId);
                  final isOwner = currentUserId != null &&
                      _reviews[i].userId == currentUserId;
                  return ReviewCard(
                    review: _reviews[i],
                    isLiked: alreadyLiked,
                    onLike: isSignedIn && !alreadyLiked
                        ? () async {
                            await ref
                                .read(reviewNotifierProvider.notifier)
                                .likeReview(reviewId);
                            ref.invalidate(
                                likedReviewIdsProvider(facility.id));
                          }
                        : null,
                    onUnlike: isSignedIn && alreadyLiked
                        ? () async {
                            await ref
                                .read(reviewNotifierProvider.notifier)
                                .unlikeReview(reviewId);
                            ref.invalidate(
                                likedReviewIdsProvider(facility.id));
                          }
                        : null,
                    onEdit: isOwner
                        ? () async {
                            await showModalBottomSheet<void>(
                              context: context,
                              isScrollControlled: true,
                              builder: (_) => ReviewBottomSheet(
                                facilityId: widget.facilityId,
                                existingReviewId: reviewId,
                                existingContent: _reviews[i].content,
                                existingRating: _reviews[i].rating,
                                onSubmitted: () {
                                  _loadReviews();
                                  ref.invalidate(
                                      facilityReviewSummaryProvider(
                                          facility.id));
                                },
                              ),
                            );
                          }
                        : null,
                    onDelete: isOwner
                        ? () async {
                            await ref
                                .read(reviewNotifierProvider.notifier)
                                .deleteReview(reviewId);
                            _loadReviews();
                            ref.invalidate(
                                facilityReviewSummaryProvider(facility.id));
                          }
                        : null,
                  );
                },
                childCount: _reviews.length,
              ),
            ),

          if (!_reviewInitialLoading)
            SliverToBoxAdapter(
              child: _ReviewFooter(
                loadingMore: _reviewLoadingMore,
                hasMore: _reviewHasMore,
                reviewCount: _reviews.length,
              ),
            ),

          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Center(child: BannerAdWidget()),
            ),
          ),

          SliverToBoxAdapter(
            child: SizedBox(
              height: MediaQuery.of(context).padding.bottom + 16,
            ),
          ),
        ],
      ),
    );
  }
}
