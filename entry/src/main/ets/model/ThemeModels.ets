export type ThemeId = 'gold' | 'ocean' | 'forest'

export type ColorModePreference = 'SYSTEM' | 'LIGHT' | 'DARK'

export interface ThemePalette {
  page: string
  card: string
  surface: string
  primary: string
  primarySoft: string
  text: string
  secondary: string
  muted: string
  divider: string
  success: string
  successSoft: string
  warning: string
  warningSoft: string
  danger: string
  dangerSoft: string
  purple: string
  purpleSoft: string
  warm: string
  cardPressed: string
  border: string
  shadow: string
  shadowStrong: string
  iconPrimary: string
  iconSuccess: string
  iconWarning: string
  iconDanger: string
  iconPurple: string
  heroStart: string
  heroEnd: string
  heroText: string
  heroShadow: string
  navBackground: string
  navIndicator: string
  chartGrid: string
  chartInner: string
}

export interface ThemeSettings {
  themeId: ThemeId
  colorModePreference: ColorModePreference
}

export interface ThemeOption {
  id: ThemeId
  name: string
  description: string
  previewStart: string
  previewEnd: string
}

const GOLD_LIGHT: ThemePalette = {
  page: '#F5F7FA',
  card: '#FFFFFF',
  surface: '#FAF8F4',
  primary: '#CFA356',
  primarySoft: '#FFFAEE',
  text: '#302008',
  secondary: '#5C5140',
  muted: '#948A7B',
  divider: '#EDE5D6',
  success: '#21A77A',
  successSoft: '#EAF8F2',
  warning: '#D88A2B',
  warningSoft: '#FFF4E8',
  danger: '#D85D62',
  dangerSoft: '#FFF0F1',
  purple: '#8171C8',
  purpleSoft: '#F0EDFF',
  warm: '#E8A164',
  cardPressed: '#FFF8E8',
  border: '#0B000000',
  shadow: '#12000000',
  shadowStrong: '#16000000',
  iconPrimary: '#16CFA356',
  iconSuccess: '#1621A77A',
  iconWarning: '#16D88A2B',
  iconDanger: '#16D85D62',
  iconPurple: '#168171C8',
  heroStart: '#FBE7B7',
  heroEnd: '#CFA356',
  heroText: '#302008',
  heroShadow: '#40E6C07B',
  navBackground: '#C7FFFFFF',
  navIndicator: '#2ECFA356',
  chartGrid: '#18D9D0C4',
  chartInner: '#FFFFFFFF'
}

const GOLD_DARK: ThemePalette = {
  page: '#10100F',
  card: '#1C1A17',
  surface: '#242019',
  primary: '#E3B968',
  primarySoft: '#382D1A',
  text: '#FFF4DF',
  secondary: '#C8BBA6',
  muted: '#948875',
  divider: '#3A3328',
  success: '#45D69F',
  successSoft: '#17352B',
  warning: '#F0AD54',
  warningSoft: '#3B2916',
  danger: '#F0787C',
  dangerSoft: '#3B2023',
  purple: '#A99BFF',
  purpleSoft: '#2A2544',
  warm: '#F1B078',
  cardPressed: '#332A1C',
  border: '#20FFFFFF',
  shadow: '#52000000',
  shadowStrong: '#65000000',
  iconPrimary: '#35CFA356',
  iconSuccess: '#3521A77A',
  iconWarning: '#35D88A2B',
  iconDanger: '#35D85D62',
  iconPurple: '#358171C8',
  heroStart: '#6D5322',
  heroEnd: '#B18035',
  heroText: '#FFF4DF',
  heroShadow: '#55000000',
  navBackground: '#D21C1A17',
  navIndicator: '#40E3B968',
  chartGrid: '#304A4438',
  chartInner: '#FFFFFFFF'
}

const OCEAN_LIGHT: ThemePalette = {
  page: '#F2F7FB',
  card: '#FFFFFF',
  surface: '#F1F8FC',
  primary: '#1877B8',
  primarySoft: '#E8F4FC',
  text: '#102A43',
  secondary: '#486581',
  muted: '#829AB1',
  divider: '#D9EAF5',
  success: '#138A68',
  successSoft: '#E7F7F1',
  warning: '#C87818',
  warningSoft: '#FFF3E2',
  danger: '#C94C5B',
  dangerSoft: '#FDECEF',
  purple: '#6B63B5',
  purpleSoft: '#F0EEFF',
  warm: '#E38B54',
  cardPressed: '#E7F4FC',
  border: '#0B1877B8',
  shadow: '#1210264A',
  shadowStrong: '#1600264A',
  iconPrimary: '#181877B8',
  iconSuccess: '#18138A68',
  iconWarning: '#18C87818',
  iconDanger: '#18C94C5B',
  iconPurple: '#186B63B5',
  heroStart: '#B8E3F7',
  heroEnd: '#4E9FD0',
  heroText: '#102A43',
  heroShadow: '#40518FB1',
  navBackground: '#C7FFFFFF',
  navIndicator: '#301877B8',
  chartGrid: '#182D86AD',
  chartInner: '#FFFFFFFF'
}

const OCEAN_DARK: ThemePalette = {
  page: '#0C1720',
  card: '#142632',
  surface: '#1B3441',
  primary: '#61B8EC',
  primarySoft: '#173A52',
  text: '#E7F5FF',
  secondary: '#A8C5D8',
  muted: '#7594A8',
  divider: '#294654',
  success: '#51D5AA',
  successSoft: '#153D36',
  warning: '#F0B35B',
  warningSoft: '#46321B',
  danger: '#F17D89',
  dangerSoft: '#48252D',
  purple: '#B4A8FF',
  purpleSoft: '#302C54',
  warm: '#F2A977',
  cardPressed: '#1B3A4B',
  border: '#2861B8EC',
  shadow: '#55000000',
  shadowStrong: '#65000000',
  iconPrimary: '#3561B8EC',
  iconSuccess: '#3551D5AA',
  iconWarning: '#35F0B35B',
  iconDanger: '#35F17D89',
  iconPurple: '#35B4A8FF',
  heroStart: '#1E5878',
  heroEnd: '#246F9B',
  heroText: '#E7F5FF',
  heroShadow: '#55000000',
  navBackground: '#D2142632',
  navIndicator: '#4061B8EC',
  chartGrid: '#305B8294',
  chartInner: '#FFFFFFFF'
}

const FOREST_LIGHT: ThemePalette = {
  page: '#F3F8F4',
  card: '#FFFFFF',
  surface: '#F2F8F2',
  primary: '#31845B',
  primarySoft: '#E8F5EC',
  text: '#173A2A',
  secondary: '#4B6B59',
  muted: '#849B8C',
  divider: '#DCEBE0',
  success: '#168A63',
  successSoft: '#E5F7EF',
  warning: '#C27A25',
  warningSoft: '#FFF3E2',
  danger: '#C95A63',
  dangerSoft: '#FDECEF',
  purple: '#7769B8',
  purpleSoft: '#F1EEFF',
  warm: '#D88754',
  cardPressed: '#E7F5EB',
  border: '#0B31845B',
  shadow: '#121D4A2B',
  shadowStrong: '#161D4A2B',
  iconPrimary: '#1831845B',
  iconSuccess: '#18168A63',
  iconWarning: '#18C27A25',
  iconDanger: '#18C95A63',
  iconPurple: '#187769B8',
  heroStart: '#C5E8C8',
  heroEnd: '#6FB47F',
  heroText: '#173A2A',
  heroShadow: '#405C9F6D',
  navBackground: '#C7FFFFFF',
  navIndicator: '#3031845B',
  chartGrid: '#183B8F64',
  chartInner: '#FFFFFFFF'
}

const FOREST_DARK: ThemePalette = {
  page: '#0D1813',
  card: '#16261D',
  surface: '#1D3326',
  primary: '#78D39A',
  primarySoft: '#183C29',
  text: '#E7F8EC',
  secondary: '#ACCEB6',
  muted: '#789882',
  divider: '#2D4936',
  success: '#55D8A6',
  successSoft: '#153D32',
  warning: '#E8AF5B',
  warningSoft: '#44331B',
  danger: '#F17D87',
  dangerSoft: '#47252B',
  purple: '#B5A9FF',
  purpleSoft: '#302A50',
  warm: '#F0A777',
  cardPressed: '#1C3C29',
  border: '#2878D39A',
  shadow: '#55000000',
  shadowStrong: '#65000000',
  iconPrimary: '#3578D39A',
  iconSuccess: '#3555D8A6',
  iconWarning: '#35E8AF5B',
  iconDanger: '#35F17D87',
  iconPurple: '#35B5A9FF',
  heroStart: '#2D6942',
  heroEnd: '#3D9560',
  heroText: '#E7F8EC',
  heroShadow: '#55000000',
  navBackground: '#D216261D',
  navIndicator: '#4078D39A',
  chartGrid: '#304D805B',
  chartInner: '#FFFFFFFF'
}

export const THEME_OPTIONS: ThemeOption[] = [
  { id: 'gold', name: '星辉金', description: '温暖沉稳的监控主题', previewStart: GOLD_LIGHT.heroStart, previewEnd: GOLD_LIGHT.heroEnd },
  { id: 'ocean', name: '深海蓝', description: '清爽克制的科技主题', previewStart: OCEAN_LIGHT.heroStart, previewEnd: OCEAN_LIGHT.heroEnd },
  { id: 'forest', name: '森野绿', description: '自然平衡的运维主题', previewStart: FOREST_LIGHT.heroStart, previewEnd: FOREST_LIGHT.heroEnd }
]

export function getThemePalette(themeId: ThemeId, darkMode: boolean): ThemePalette {
  if (themeId === 'ocean') return darkMode ? OCEAN_DARK : OCEAN_LIGHT
  if (themeId === 'forest') return darkMode ? FOREST_DARK : FOREST_LIGHT
  return darkMode ? GOLD_DARK : GOLD_LIGHT
}
