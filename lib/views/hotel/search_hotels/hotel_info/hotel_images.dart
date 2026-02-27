import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:photo_view/photo_view.dart';
import 'package:photo_view/photo_view_gallery.dart';
import 'package:ready_flights/utility/colors.dart';

class HotelImagesGalleryScreen extends StatefulWidget {
  final List<String> images;
  final String hotelName;
  final int initialIndex;

  const HotelImagesGalleryScreen({
    Key? key,
    required this.images,
    required this.hotelName,
    this.initialIndex = 0,
  }) : super(key: key);

  @override
  State<HotelImagesGalleryScreen> createState() => _HotelImagesGalleryScreenState();
}

class _HotelImagesGalleryScreenState extends State<HotelImagesGalleryScreen>
    with SingleTickerProviderStateMixin {
  late PageController _pageController;
  late int _currentIndex;
  bool _showThumbnails = true;
  bool _showUI = true;
  late AnimationController _animationController;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: widget.initialIndex);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    _fadeAnimation = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
    
    // Auto-hide UI after 3 seconds
    _startAutoHideTimer();
  }

  void _startAutoHideTimer() {
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted && _showUI) {
        _toggleUI();
      }
    });
  }

  void _toggleUI() {
    setState(() {
      _showUI = !_showUI;
    });
    if (_showUI) {
      _animationController.reverse();
      _startAutoHideTimer();
    } else {
      _animationController.forward();
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: TColors.black,
      body: GestureDetector(
        onTap: _toggleUI,
        child: Stack(
          children: [
            // Main photo gallery
            PhotoViewGallery.builder(
              scrollPhysics: const BouncingScrollPhysics(),
              builder: (BuildContext context, int index) {
                return PhotoViewGalleryPageOptions(
                  imageProvider: CachedNetworkImageProvider(widget.images[index]),
                  initialScale: PhotoViewComputedScale.contained,
                  heroAttributes: PhotoViewHeroAttributes(tag: widget.images[index]),
                  minScale: PhotoViewComputedScale.contained * 0.8,
                  maxScale: PhotoViewComputedScale.covered * 3,
                  errorBuilder: (context, error, stackTrace) {
                    return Container(
                      color: TColors.grey.withOpacity(0.3),
                      child: const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.image_not_supported,
                              size: 64,
                              color: TColors.grey,
                            ),
                            SizedBox(height: 8),
                            Text(
                              'Failed to load image',
                              style: TextStyle(color: TColors.grey),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
              itemCount: widget.images.length,
              loadingBuilder: (context, event) => Container(
                color: TColors.black,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
                      ),
                      SizedBox(height: 16),
                      Text(
                        'Loading image...',
                        style: TextStyle(color: TColors.white),
                      ),
                    ],
                  ),
                ),
              ),
              backgroundDecoration: const BoxDecoration(
                color: TColors.black,
              ),
              pageController: _pageController,
              onPageChanged: (int index) {
                setState(() {
                  _currentIndex = index;
                });
              },
            ),

            // Top UI (App Bar with Back Button)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return AnimatedOpacity(
                  opacity: _showUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.black.withOpacity(0.8),
                          Colors.transparent,
                        ],
                      ),
                    ),
                    child: SafeArea(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            // Back Button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: const Icon(
                                  Icons.close,
                                  color: TColors.white,
                                  size: 24,
                                ),
                                onPressed: () {
                                  if (mounted) {
                                    Navigator.of(context).pop();
                                  }
                                },
                              ),
                            ),
                            
                            const Spacer(),
                            
                            // Grid View Toggle Button
                            Container(
                              decoration: BoxDecoration(
                                color: Colors.black.withOpacity(0.5),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: IconButton(
                                icon: Icon(
                                  _showThumbnails ? Icons.grid_view : Icons.view_stream,
                                  color: TColors.white,
                                ),
                                onPressed: () {
                                  setState(() {
                                    _showThumbnails = !_showThumbnails;
                                  });
                                  if (!_showThumbnails) {
                                    _showThumbnailGrid();
                                  }
                                },
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Bottom thumbnail strip
            if (_showThumbnails)
              AnimatedBuilder(
                animation: _fadeAnimation,
                builder: (context, child) {
                  return AnimatedPositioned(
                    duration: const Duration(milliseconds: 300),
                    bottom: _showUI ? 20 : -120,
                    left: 0,
                    right: 0,
                    child: AnimatedOpacity(
                      opacity: _showUI ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 300),
                      child: Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.bottomCenter,
                            end: Alignment.topCenter,
                            colors: [
                              Colors.black.withOpacity(0.8),
                              Colors.transparent,
                            ],
                          ),
                        ),
                        child: Container(
                          height: 100,
                          padding: const EdgeInsets.all(20),
                          child: ListView.builder(
                            scrollDirection: Axis.horizontal,
                            itemCount: widget.images.length,
                            itemBuilder: (context, index) {
                              bool isSelected = _currentIndex == index;
                              return GestureDetector(
                                onTap: () {
                                  _pageController.animateToPage(
                                    index,
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                },
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: isSelected ? 80 : 60,
                                  height: isSelected ? 80 : 60,
                                  margin: const EdgeInsets.only(right: 12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: isSelected 
                                          ? TColors.primary 
                                          : Colors.white.withOpacity(0.3),
                                      width: isSelected ? 3 : 1,
                                    ),
                                    boxShadow: isSelected ? [
                                      BoxShadow(
                                        color: TColors.primary.withOpacity(0.5),
                                        blurRadius: 8,
                                        spreadRadius: 1,
                                      ),
                                    ] : null,
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(10),
                                    child: CachedNetworkImage(
                                      imageUrl: widget.images[index],
                                      fit: BoxFit.cover,
                                      placeholder: (context, url) => Container(
                                        color: TColors.grey.withOpacity(0.3),
                                        child: const Center(
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
                                          ),
                                        ),
                                      ),
                                      errorWidget: (context, url, error) => Container(
                                        color: TColors.grey.withOpacity(0.3),
                                        child: const Icon(
                                          Icons.image_not_supported,
                                          color: TColors.grey,
                                          size: 20,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),

            // Page indicator dots (center top)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return AnimatedOpacity(
                  opacity: _showUI ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 300),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 80),
                      child: Center(
                        child: Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.6),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: List.generate(
                              widget.images.length > 10 ? 10 : widget.images.length,
                              (index) => AnimatedContainer(
                                duration: const Duration(milliseconds: 300),
                                width: _currentIndex == index ? 20 : 6,
                                height: 6,
                                margin: const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(3),
                                  color: _currentIndex == index
                                      ? TColors.primary
                                      : TColors.white.withOpacity(0.5),
                                ),
                              ),
                            )..addAll(
                              widget.images.length > 10 ? [
                                Container(
                                  margin: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Text(
                                    '...',
                                    style: TextStyle(
                                      color: TColors.white.withOpacity(0.7),
                                      fontSize: 12,
                                    ),
                                  ),
                                ),
                              ] : [],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),

            // Image counter overlay (bottom right)
            AnimatedBuilder(
              animation: _fadeAnimation,
              builder: (context, child) {
                return AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  bottom: _showUI ? 140 : 20,
                  right: 20,
                  child: AnimatedOpacity(
                    opacity: _showUI ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 300),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.black.withOpacity(0.7),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: TColors.primary.withOpacity(0.3)),
                      ),
                      child: Text(
                        '${_currentIndex + 1}/${widget.images.length}',
                        style: const TextStyle(
                          color: TColors.white,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  void _showThumbnailGrid() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => DraggableScrollableSheet(
        initialChildSize: 0.7,
        maxChildSize: 0.9,
        minChildSize: 0.5,
        builder: (context, scrollController) => Container(
          decoration: const BoxDecoration(
            color: TColors.background4,
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          child: Column(
            children: [
              // Handle
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: TColors.grey.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              
              // Header
              Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'All Photos',
                          style: const TextStyle(
                            color: TColors.white,
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '${widget.images.length} images',
                          style: TextStyle(
                            color: TColors.grey.withOpacity(0.8),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: TColors.white),
                      onPressed: () {
                        if (mounted) {
                          Navigator.pop(context);
                        }
                      },
                      style: IconButton.styleFrom(
                        backgroundColor: TColors.grey.withOpacity(0.2),
                        padding: const EdgeInsets.all(8),
                      ),
                    ),
                  ],
                ),
              ),
              
              // Grid
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: GridView.builder(
                    controller: scrollController,
                    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: 3,
                      crossAxisSpacing: 8,
                      mainAxisSpacing: 8,
                      childAspectRatio: 1,
                    ),
                    itemCount: widget.images.length,
                    itemBuilder: (context, index) {
                      bool isSelected = _currentIndex == index;
                      return GestureDetector(
                        onTap: () {
                          if (mounted) {
                            Navigator.pop(context);
                            _pageController.animateToPage(
                              index,
                              duration: const Duration(milliseconds: 300),
                              curve: Curves.easeInOut,
                            );
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected 
                                  ? TColors.primary 
                                  : Colors.transparent,
                              width: 3,
                            ),
                          ),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(10),
                            child: Stack(
                              fit: StackFit.expand,
                              children: [
                                CachedNetworkImage(
                                  imageUrl: widget.images[index],
                                  fit: BoxFit.cover,
                                  placeholder: (context, url) => Container(
                                    color: TColors.grey.withOpacity(0.3),
                                    child: const Center(
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        valueColor: AlwaysStoppedAnimation<Color>(TColors.primary),
                                      ),
                                    ),
                                  ),
                                  errorWidget: (context, url, error) => Container(
                                    color: TColors.grey.withOpacity(0.3),
                                    child: const Icon(
                                      Icons.image_not_supported,
                                      color: TColors.grey,
                                      size: 30,
                                    ),
                                  ),
                                ),
                                if (isSelected)
                                  Container(
                                    decoration: BoxDecoration(
                                      color: TColors.primary.withOpacity(0.3),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: const Center(
child: Icon(
        Icons.check_circle,
        color: TColors.iconclr,
                                        size: 30,
                                      ),
                                    ),
                                  ),
                                
                                // Image number
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.black.withOpacity(0.7),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: TColors.white,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    ).then((_) {
      setState(() {
        _showThumbnails = true;
      });
    });
  }
}