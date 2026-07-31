"""
Restructures both onboarding flows so dots + button are inside each PageView page
(not fixed outside it). This makes them scroll/slide with the page, and the
content above them is independently scrollable within each page.
"""
import re

# ─── CANDIDATE FLOW ───────────────────────────────────────────────────────────

with open(r'c:\SkillSense AI\lib\screens\candidate\candidate_onboarding_flow.dart', 'r', encoding='utf-8') as f:
    cand = f.read()

# 1. Add _buildControls() helper method right before @override Widget build
build_controls_method = r'''
  // Bottom controls shared by all pages
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(5, (index) {
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _InteractiveDot(isActive: _currentPage == index),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF34C759),
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: const Color(0xFF34C759).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                _currentPage == 4
                    ? 'Create my account'
                    : AppConstants.candidateNextButton,
                style: GoogleFonts.publicSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

'''

cand = cand.replace(
    '  @override\n  Widget build(BuildContext context) {',
    build_controls_method + '  @override\n  Widget build(BuildContext context) {',
    1
)

# 2. Remove the fixed bottom Controls Padding block.
# It starts at "                // Bottom Controls" and ends just before the closing
# brackets of the SafeArea Column
fixed_bottom = (
    '\n                // Bottom Controls\n'
    '                Padding(\n'
    '                  padding: const EdgeInsets.all(24.0),\n'
    '                  child: Column(\n'
    '                    children: [\n'
    '                      // Page Indicators\n'
    '                      Row(\n'
    '                        mainAxisAlignment: MainAxisAlignment.center,\n'
    '                        children: List.generate(5, (index) {\n'
    '                          return GestureDetector(\n'
    '                            onTap: () {\n'
    '                              _pageController.animateToPage(\n'
    '                                index,\n'
    '                                duration: const Duration(milliseconds: 300),\n'
    '                                curve: Curves.easeInOut,\n'
    '                              );\n'
    '                            },\n'
    '                            child: Padding(\n'
    '                              padding: const EdgeInsets.symmetric(\n'
    '                                horizontal: 4.0,\n'
    '                              ),\n'
    '                              child: _InteractiveDot(\n'
    '                                isActive: _currentPage == index,\n'
    '                              ),\n'
    '                            ),\n'
    '                          );\n'
    '                        }),\n'
    '                      ),\n'
    '                      const SizedBox(height: 24),\n'
    '                      // Next Button\n'
    '                      SizedBox(\n'
    '                        width: 220,\n'
    '                        height: 56,\n'
    '                        child: ElevatedButton(\n'
    '                          onPressed: _nextPage,\n'
    '                          style: ElevatedButton.styleFrom(\n'
    '                            backgroundColor: const Color(0xFF34C759),\n'
    '                            foregroundColor: Colors.white,\n'
    '                            elevation: 10,\n'
    '                            shadowColor: const Color(\n'
    '                              0xFF34C759,\n'
    '                            ).withValues(alpha: 0.3),\n'
    '                            shape: RoundedRectangleBorder(\n'
    '                              borderRadius: BorderRadius.circular(28),\n'
    '                            ),\n'
    '                          ),\n'
    '                          child: Text(\n'
    '                            _currentPage == 4\n'
    '                                ? \'Create my account\'\n'
    '                                : AppConstants.candidateNextButton,\n'
    '                            style: GoogleFonts.publicSans(\n'
    '                              fontSize: 18,\n'
    '                              fontWeight: FontWeight.w600,\n'
    '                            ),\n'
    '                          ),\n'
    '                        ),\n'
    '                      ),\n'
    '                    ],\n'
    '                  ),\n'
    '                ),'
)
cand = cand.replace(fixed_bottom, '', 1)

# 3. Wrap each SingleChildScrollView page with a Column so content scrolls
# but controls sit below it (fixed within the page, not the screen).
#
# Before:
#   // Page N
#   SingleChildScrollView(
#     physics: const BouncingScrollPhysics(),
#     child: Padding(
#       ...content...
#       const SizedBox(height: 32),
#     ],),),),
#
# After:
#   // Page N
#   Column(
#     children: [
#       Expanded(
#         child: SingleChildScrollView(
#           physics: const BouncingScrollPhysics(),
#           child: Padding(
#             ...content...
#             const SizedBox(height: 32),
#           ],),),),
#       ),
#       _buildControls(),
#     ],
#   ),

OLD_PAGE_OPEN = (
    '                      SingleChildScrollView(\n'
    '                        physics: const BouncingScrollPhysics(),\n'
    '                        child: Padding(\n'
    '                          padding: const EdgeInsets.symmetric(horizontal: 24.0),\n'
    '                          child: Column(\n'
    '                            children: [\n'
)

NEW_PAGE_OPEN = (
    '                      Column(\n'
    '                        children: [\n'
    '                          Expanded(\n'
    '                            child: SingleChildScrollView(\n'
    '                              physics: const BouncingScrollPhysics(),\n'
    '                              child: Padding(\n'
    '                                padding: const EdgeInsets.symmetric(horizontal: 24.0),\n'
    '                                child: Column(\n'
    '                                  children: [\n'
)

# Each page ends with this exact closing sequence (content last line is SizedBox(height:32))
OLD_PAGE_CLOSE = (
    '                              const SizedBox(height: 32),\n'
    '                            ],\n'
    '                          ),\n'
    '                        ),\n'
    '                      ),'
)

NEW_PAGE_CLOSE = (
    '                                  const SizedBox(height: 32),\n'
    '                                ],\n'
    '                              ),\n'
    '                            ),\n'
    '                          ),\n'
    '                        ),\n'
    '                      ),\n'
    '                          _buildControls(),\n'
    '                        ],\n'
    '                      ),'
)

# Content lines inside each page need 8 more spaces of indentation.
# Find each page block and re-indent its content lines.
# Strategy: replace OLD_PAGE_OPEN and OLD_PAGE_CLOSE, then fix content indentation.

# We'll process page by page by finding occurrences of OLD_PAGE_OPEN
# and finding the corresponding OLD_PAGE_CLOSE.

result = ''
remaining = cand
open_marker = OLD_PAGE_OPEN

while open_marker in remaining:
    pre, _, after_open = remaining.partition(open_marker)
    
    # Find corresponding close
    close_idx = after_open.find(OLD_PAGE_CLOSE)
    if close_idx == -1:
        # No more closes, stop
        result += pre + open_marker + after_open
        remaining = ''
        break
    
    content_block = after_open[:close_idx]
    after_close = after_open[close_idx + len(OLD_PAGE_CLOSE):]
    
    # Re-indent content_block: add 8 spaces to each line
    re_indented = '\n'.join(
        ('        ' + line) if line.strip() else line
        for line in content_block.split('\n')
    )
    
    result += pre + NEW_PAGE_OPEN + re_indented + NEW_PAGE_CLOSE
    remaining = after_close

result += remaining
cand = result

with open(r'c:\SkillSense AI\lib\screens\candidate\candidate_onboarding_flow.dart', 'w', encoding='utf-8') as f:
    f.write(cand)

print('Candidate flow done.')

# ─── HR FLOW ──────────────────────────────────────────────────────────────────

with open(r'c:\SkillSense AI\lib\screens\hr\hr_onboarding_flow.dart', 'r', encoding='utf-8') as f:
    hr = f.read()

# The HR flow has separate page widgets (_Page1 ... _Page4).
# Each page uses a SingleChildScrollView inside a build() returning that widget.
# Strategy: in HrOnboardingFlow, pass a `controls` widget to each page,
# OR (simpler) change each Page widget to include its own controls row.

# Actually simpler: since HR pages are separate widgets,
# let's convert the HrOnboardingFlow to pass controller/currentPage/totalPages/onNext/onTapDot
# to each page and have them build their own controls.

# Even simpler: just restructure the HR build() so each page in PageView is:
# Column([Expanded(child: original_page_scrollview), bottom_controls_row])
# where bottom_controls is built inline.

# The HR bottom controls section to remove:
hr_fixed_bottom = (
    '\n                // Bottom controls\n'
    '                Padding(\n'
    '                  padding: const EdgeInsets.all(24.0),\n'
    '                  child: Column(\n'
    '                    children: [\n'
    '                      // Dot indicators\n'
    '                      Row(\n'
    '                        mainAxisAlignment: MainAxisAlignment.center,\n'
    '                        children: List.generate(_totalPages, (index) {\n'
    '                          return GestureDetector(\n'
    '                            onTap: () {\n'
    '                              _pageController.animateToPage(\n'
    '                                index,\n'
    '                                duration: const Duration(milliseconds: 300),\n'
    '                                curve: Curves.easeInOut,\n'
    '                              );\n'
    '                            },\n'
    '                            child: Padding(\n'
    '                              padding: const EdgeInsets.symmetric(horizontal: 4.0),\n'
    '                              child: _InteractiveDot(isActive: _currentPage == index),\n'
    '                            ),\n'
    '                          );\n'
    '                        }),\n'
    '                      ),\n'
    '                      const SizedBox(height: 24),\n'
    '                      // Next / Create account button\n'
    '                      SizedBox(\n'
    '                        width: 220,\n'
    '                        height: 56,\n'
    '                        child: ElevatedButton(\n'
    '                          onPressed: _nextPage,\n'
    '                          style: ElevatedButton.styleFrom(\n'
    '                            backgroundColor: const Color(0xFF4376F8),\n'
    '                            foregroundColor: Colors.white,\n'
    '                            elevation: 10,\n'
    '                            shadowColor: const Color(0xFF4376F8).withValues(alpha: 0.3),\n'
    '                            shape: RoundedRectangleBorder(\n'
    '                              borderRadius: BorderRadius.circular(28),\n'
    '                            ),\n'
    '                          ),\n'
    '                          child: Text(\n'
    '                            _currentPage == _totalPages - 1\n'
    '                                ? \'Create my account\'\n'
    '                                : AppConstants.hrNextButton,\n'
    '                            style: GoogleFonts.publicSans(\n'
    '                              fontSize: 18,\n'
    '                              fontWeight: FontWeight.w600,\n'
    '                            ),\n'
    '                          ),\n'
    '                        ),\n'
    '                      ),\n'
    '                    ],\n'
    '                  ),\n'
    '                ),'
)
hr = hr.replace(hr_fixed_bottom, '', 1)

# Now the PageView children are _Page1(), _Page2(), etc. (const).
# We need to wrap each in a Column with Expanded + controls.
# Add a _buildHrControls() method to the state.

hr_controls_method = r'''
  Widget _buildControls() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_totalPages, (index) {
              return GestureDetector(
                onTap: () {
                  _pageController.animateToPage(
                    index,
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeInOut,
                  );
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4.0),
                  child: _InteractiveDot(isActive: _currentPage == index),
                ),
              );
            }),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: 220,
            height: 56,
            child: ElevatedButton(
              onPressed: _nextPage,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4376F8),
                foregroundColor: Colors.white,
                elevation: 10,
                shadowColor: const Color(0xFF4376F8).withValues(alpha: 0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(28),
                ),
              ),
              child: Text(
                _currentPage == _totalPages - 1
                    ? 'Create my account'
                    : AppConstants.hrNextButton,
                style: GoogleFonts.publicSans(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

'''

hr = hr.replace(
    '  @override\n  Widget build(BuildContext context) {',
    hr_controls_method + '  @override\n  Widget build(BuildContext context) {',
    1
)

# Wrap each const _PageN() in Column with Expanded + controls
# Pattern: "                      const _Page1(),"
for i in range(1, 5):
    old = f'                      const _Page{i}(),'
    new = (
        f'                      Column(\n'
        f'                        children: [\n'
        f'                          Expanded(child: _Page{i}()),\n'
        f'                          _buildControls(),\n'
        f'                        ],\n'
        f'                      ),'
    )
    hr = hr.replace(old, new, 1)

with open(r'c:\SkillSense AI\lib\screens\hr\hr_onboarding_flow.dart', 'w', encoding='utf-8') as f:
    f.write(hr)

print('HR flow done.')
