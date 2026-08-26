import localUnitTest from './LocalUnit.test';
import responsiveLayoutTest from './ResponsiveLayout.test';

export default function testsuite(): void {
  localUnitTest();
  responsiveLayoutTest();
}
