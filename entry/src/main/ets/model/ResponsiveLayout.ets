export type LayoutSize = 'compact' | 'medium' | 'expanded'

export function getLayoutSize(windowWidthVp: number): LayoutSize {
  if (windowWidthVp < 600) {
    return 'compact'
  }
  if (windowWidthVp < 840) {
    return 'medium'
  }
  return 'expanded'
}

export function isCompactLayout(layoutSize: LayoutSize): boolean {
  return layoutSize === 'compact'
}

export function isWideLayout(layoutSize: LayoutSize): boolean {
  return layoutSize !== 'compact'
}

export function isExpandedLayout(layoutSize: LayoutSize): boolean {
  return layoutSize === 'expanded'
}

export function getNavigationWidth(layoutSize: LayoutSize): number {
  return 0
}

export function getPageHorizontalPadding(layoutSize: LayoutSize): number {
  if (layoutSize === 'compact') {
    return 18
  }
  if (layoutSize === 'medium') {
    return 24
  }
  return 32
}

export function getContentMaxWidth(layoutSize: LayoutSize, availableWidthVp: number): number {
  if (layoutSize === 'compact') {
    return availableWidthVp > 0 ? availableWidthVp : 0
  }
  if (layoutSize === 'medium') {
    return 720
  }
  return 1200
}

export function getMainBottomInset(layoutSize: LayoutSize, safeAreaVp: number): number {
  return 32
}

export function getClampedWidth(availableWidthVp: number, maximumWidthVp: number): number {
  if (availableWidthVp <= 0 || maximumWidthVp <= 0) {
    return 0
  }
  return availableWidthVp < maximumWidthVp ? availableWidthVp : maximumWidthVp
}

export function getSheetWidth(windowWidthVp: number, layoutSize: LayoutSize,
  mediumMaximumWidthVp: number, expandedMaximumWidthVp: number): number {
  if (layoutSize === 'compact') {
    return windowWidthVp > 0 ? windowWidthVp : 0
  }
  const availableWidthVp: number = windowWidthVp - getPageHorizontalPadding(layoutSize) * 2
  if (layoutSize === 'medium') {
    return getClampedWidth(availableWidthVp, mediumMaximumWidthVp)
  }
  return getClampedWidth(availableWidthVp, expandedMaximumWidthVp)
}

export function getDetailPanelWidth(windowWidthVp: number, layoutSize: LayoutSize): number {
  if (windowWidthVp <= 0) {
    return 0
  }
  if (layoutSize === 'compact') {
    return windowWidthVp * 0.9
  }
  if (layoutSize === 'medium') {
    return getClampedWidth(windowWidthVp - 48, 680)
  }
  const availableWidthVp: number = windowWidthVp - 64
  if (availableWidthVp <= 560) {
    return availableWidthVp > 0 ? availableWidthVp : 0
  }
  const preferredWidthVp: number = windowWidthVp * 0.4
  if (preferredWidthVp < 560) {
    return 560
  }
  return getClampedWidth(availableWidthVp, preferredWidthVp < 620 ? preferredWidthVp : 620)
}

export function getTrendChartHeight(layoutSize: LayoutSize): number {
  if (layoutSize === 'compact') {
    return 190
  }
  if (layoutSize === 'medium') {
    return 230
  }
  return 270
}
