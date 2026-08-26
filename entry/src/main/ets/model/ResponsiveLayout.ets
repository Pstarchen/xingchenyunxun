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

export function getServiceContentMaxWidth(layoutSize: LayoutSize, availableWidthVp: number): number {
  if (availableWidthVp <= 0) {
    return 0
  }
  if (layoutSize === 'compact') {
    return getClampedWidth(availableWidthVp, availableWidthVp)
  }
  if (layoutSize === 'medium') {
    return getClampedWidth(availableWidthVp, 720)
  }
  return getClampedWidth(availableWidthVp, 736)
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
  const availableWidthVp: number = windowWidthVp - getPageHorizontalPadding(layoutSize) * 2
  return getClampedWidth(availableWidthVp, 620)
}

export function getDetailPanelHeight(windowHeightVp: number, layoutSize: LayoutSize): number {
  if (windowHeightVp <= 0) {
    return 600
  }
  if (layoutSize === 'compact') {
    return windowHeightVp * 0.75
  }
  const preferredHeightVp: number = windowHeightVp * 0.82
  const availableHeightVp: number = windowHeightVp - 48
  return preferredHeightVp < availableHeightVp ? preferredHeightVp : availableHeightVp
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
