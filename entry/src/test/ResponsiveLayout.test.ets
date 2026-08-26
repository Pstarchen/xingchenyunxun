import { describe, expect, it } from '@ohos/hypium';
import {
  getClampedWidth,
  getContentMaxWidth,
  getDetailPanelHeight,
  getDetailPanelWidth,
  getLayoutSize,
  getMainBottomInset,
  getNavigationWidth,
  getPageHorizontalPadding,
  getServiceContentMaxWidth,
  getSheetWidth,
  getTrendChartHeight,
  isCompactLayout,
  isExpandedLayout,
  isWideLayout
} from '../main/ets/model/ResponsiveLayout';

export default function responsiveLayoutTest(): void {
  describe('responsiveLayoutTest', () => {
    it('classifiesBoundaryWidths', 0, () => {
      expect(getLayoutSize(0)).assertEqual('compact');
      expect(getLayoutSize(319)).assertEqual('compact');
      expect(getLayoutSize(320)).assertEqual('compact');
      expect(getLayoutSize(599)).assertEqual('compact');
      expect(getLayoutSize(600)).assertEqual('medium');
      expect(getLayoutSize(839)).assertEqual('medium');
      expect(getLayoutSize(840)).assertEqual('expanded');
      expect(getLayoutSize(963)).assertEqual('expanded');
      expect(getLayoutSize(964)).assertEqual('expanded');
      expect(getLayoutSize(1200)).assertEqual('expanded');
      expect(getLayoutSize(1439)).assertEqual('expanded');
      expect(getLayoutSize(1440)).assertEqual('expanded');
      expect(getLayoutSize(1600)).assertEqual('expanded');
    });

    it('returnsResponsiveGeometry', 0, () => {
      expect(getNavigationWidth('compact')).assertEqual(0);
      expect(getNavigationWidth('medium')).assertEqual(0);
      expect(getNavigationWidth('expanded')).assertEqual(0);
      expect(getPageHorizontalPadding('compact')).assertEqual(18);
      expect(getPageHorizontalPadding('medium')).assertEqual(24);
      expect(getPageHorizontalPadding('expanded')).assertEqual(32);
      expect(getContentMaxWidth('compact', 564)).assertEqual(564);
      expect(getContentMaxWidth('compact', -1)).assertEqual(0);
      expect(getContentMaxWidth('medium', 600)).assertEqual(720);
      expect(getContentMaxWidth('expanded', 840)).assertEqual(1200);
      expect(getMainBottomInset('compact', 16)).assertEqual(32);
      expect(getMainBottomInset('medium', 16)).assertEqual(32);
      expect(getMainBottomInset('expanded', 16)).assertEqual(32);
    });

    it('clampsServiceContentAtResponsiveBoundaries', 0, () => {
      expect(getServiceContentMaxWidth('compact', 0)).assertEqual(0);
      expect(getServiceContentMaxWidth('compact', -1)).assertEqual(0);
      expect(getServiceContentMaxWidth('compact', 599)).assertEqual(599);
      expect(getServiceContentMaxWidth('medium', 600)).assertEqual(600);
      expect(getServiceContentMaxWidth('medium', 839)).assertEqual(720);
      expect(getServiceContentMaxWidth('expanded', 840)).assertEqual(736);
      expect(getServiceContentMaxWidth('expanded', 963)).assertEqual(736);
      expect(getServiceContentMaxWidth('expanded', 964)).assertEqual(736);
      expect(getServiceContentMaxWidth('expanded', 1200)).assertEqual(736);
      expect(getServiceContentMaxWidth('expanded', 1440)).assertEqual(736);
      expect(getServiceContentMaxWidth('expanded', 1600)).assertEqual(736);
      expect(getServiceContentMaxWidth('medium', 839) - getPageHorizontalPadding('medium') * 2).assertEqual(672);
      expect(getServiceContentMaxWidth('expanded', 840) - getPageHorizontalPadding('expanded') * 2).assertEqual(672);
    });

    it('clampsSheetAndDetailWidths', 0, () => {
      expect(getClampedWidth(420, 560)).assertEqual(420);
      expect(getClampedWidth(720, 560)).assertEqual(560);
      expect(getClampedWidth(-1, 560)).assertEqual(0);
      expect(getSheetWidth(320, 'compact', 560, 640)).assertEqual(320);
      expect(getSheetWidth(600, 'medium', 560, 640)).assertEqual(552);
      expect(getSheetWidth(839, 'medium', 560, 640)).assertEqual(560);
      expect(getSheetWidth(840, 'expanded', 560, 640)).assertEqual(640);
      expect(getDetailPanelWidth(0, 'compact')).assertEqual(0);
      expect(getDetailPanelWidth(360, 'compact')).assertEqual(324);
      expect(getDetailPanelWidth(599, 'compact')).assertEqual(539.1);
      expect(getDetailPanelWidth(600, 'medium')).assertEqual(552);
      expect(getDetailPanelWidth(839, 'medium')).assertEqual(620);
      expect(getDetailPanelWidth(840, 'expanded')).assertEqual(620);
      expect(getDetailPanelWidth(963, 'expanded')).assertEqual(620);
      expect(getDetailPanelWidth(964, 'expanded')).assertEqual(620);
      expect(getDetailPanelWidth(1200, 'expanded')).assertEqual(620);
      expect(getDetailPanelWidth(1440, 'expanded')).assertEqual(620);
      expect(getDetailPanelWidth(1600, 'expanded')).assertEqual(620);
    });

    it('returnsResponsiveDetailPanelHeights', 0, () => {
      expect(getDetailPanelHeight(0, 'compact')).assertEqual(600);
      expect(getDetailPanelHeight(-1, 'expanded')).assertEqual(600);
      expect(getDetailPanelHeight(800, 'compact')).assertEqual(600);
      expect(Math.round(getDetailPanelHeight(600, 'medium'))).assertEqual(492);
      expect(Math.round(getDetailPanelHeight(600, 'expanded'))).assertEqual(492);
      expect(Math.round(getDetailPanelHeight(800, 'medium'))).assertEqual(656);
      expect(Math.round(getDetailPanelHeight(800, 'expanded'))).assertEqual(656);
      expect(Math.round(getDetailPanelHeight(200, 'medium'))).assertEqual(152);
      expect(Math.round(getDetailPanelHeight(200, 'expanded'))).assertEqual(152);
    });

    it('returnsLayoutFlagsAndChartHeights', 0, () => {
      expect(isCompactLayout('compact')).assertTrue();
      expect(isCompactLayout('medium')).assertFalse();
      expect(isWideLayout('compact')).assertFalse();
      expect(isWideLayout('medium')).assertTrue();
      expect(isExpandedLayout('medium')).assertFalse();
      expect(isExpandedLayout('expanded')).assertTrue();
      expect(getTrendChartHeight('compact')).assertEqual(190);
      expect(getTrendChartHeight('medium')).assertEqual(230);
      expect(getTrendChartHeight('expanded')).assertEqual(270);
    });
  });
}
