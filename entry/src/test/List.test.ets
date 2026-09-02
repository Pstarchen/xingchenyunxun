import localUnitTest from './LocalUnit.test';
import responsiveLayoutTest from './ResponsiveLayout.test';
import profileSecurityTest, { responseParserTest } from './ProfileSecurity.test';

export default function testsuite(): void {
  localUnitTest();
  responsiveLayoutTest();
  profileSecurityTest();
  responseParserTest();
}
