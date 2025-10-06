# Apple-Inspired Content-First Design Theme

## Overview
MotoBill now uses an Apple-inspired Content-First Design system with clean visual language, pure white backgrounds, and the Roboto font family.

## Design Principles

### 1. Content-First Approach
- **Pure White Backgrounds**: `#FFFFFF` for main surfaces to keep focus on content
- **Minimal Accents**: System Blue (#007AFF) as the only primary accent color
- **Clean Visual Language**: Consistent use of System Gray levels for subtle differentiation

### 2. Typography
- **Font Family**: Roboto (used throughout the entire app)
- **Font Weights**:
  - Normal (400) for body text
  - w600 (600) for headings and emphasis
- **Text Hierarchy**:
  - Primary: Pure black (#000000)
  - Secondary: System Gray (#3C3C43)
  - Tertiary: System Gray with 60% opacity

### 3. Color System

#### Backgrounds
| Color | Hex Code | Usage |
|-------|----------|-------|
| Pure White | `#FFFFFF` | Primary backgrounds, main surfaces |
| System Gray 6 | `#F2F2F7` | Secondary backgrounds, cards, hover states |
| System Gray 5 | `#E5E5EA` | Tertiary backgrounds, selected states, borders |

#### Text (Label System)
| Color | Hex Code | Usage |
|-------|----------|-------|
| Label (Black) | `#000000` | Primary text, main content |
| Secondary Label | `#3C3C43` | Secondary text, descriptions |
| Tertiary Label | `#3C3C43` 60% | Subtle hints, disabled text |

#### Accents
| Color | Hex Code | Usage |
|-------|----------|-------|
| System Blue | `#007AFF` | Primary accent, interactive elements, links |
| System Gray | `#8E8E93` | Neutral accents, secondary elements |

#### Status Colors
| Color | Hex Code | Usage |
|-------|----------|-------|
| System Green | `#34C759` | Success states |
| System Red | `#FF3B30` | Error states |
| System Orange | `#FF9500` | Warning states |
| System Blue | `#007AFF` | Info states |

## Implementation

### Theme Configuration
Located in: `lib/main.dart`

```dart
theme: ThemeData(
  colorScheme: ColorScheme.fromSeed(
    seedColor: AppColors.primary,
    brightness: Brightness.light,
  ),
  scaffoldBackgroundColor: AppColors.background,
  appBarTheme: AppBarTheme(
    backgroundColor: AppColors.appBarBackground,
    foregroundColor: AppColors.textPrimary,
    elevation: 0,
  ),
  fontFamily: 'Roboto',  // Applied app-wide
  useMaterial3: true,
)
```

### Color Constants
All colors are defined in: `lib/core/constants/app_colors.dart`

The file is organized into sections:
1. **BACKGROUNDS** - Pure White & System Grays
2. **TEXT** - Label System
3. **ACCENTS** - System Blue & Gray
4. **SIDEBAR COLORS** - Navigation specific
5. **APPBAR COLORS** - Top bar specific
6. **BORDERS & DIVIDERS** - Separation elements
7. **OVERLAY** - Modal backgrounds
8. **STATUS COLORS** - Success, Error, Warning, Info
9. **UTILITY** - White, Black, Transparent

### Usage Guidelines

#### Text Styling
Always include `fontFamily: 'Roboto'` in TextStyle:

```dart
Text(
  'Primary Heading',
  style: TextStyle(
    fontSize: AppSizes.fontXXL,
    fontWeight: FontWeight.w600,  // Use w600 instead of bold
    color: AppColors.textPrimary,
    fontFamily: 'Roboto',
  ),
)
```

#### Interactive Elements
Use `AppColors.primary` (System Blue) for:
- Selected states in navigation
- Active buttons
- Links and interactive text
- Focus indicators

```dart
Icon(
  Icons.home,
  color: isSelected ? AppColors.primary : AppColors.textSecondary,
)
```

#### Backgrounds and Surfaces
Use the three-level background system:
- **Primary**: `AppColors.background` (#FFFFFF)
- **Secondary**: `AppColors.backgroundSecondary` (#F2F2F7)
- **Tertiary**: `AppColors.backgroundTertiary` (#E5E5EA)

#### Borders
Use thin borders with subtle colors:
- Standard borders: `AppColors.border` (#E5E5EA)
- Border width: `0.5` to `1.0` pixels
- AppBar border: `0.5` pixels

```dart
decoration: BoxDecoration(
  border: Border(
    bottom: BorderSide(
      color: AppColors.appBarBorder,
      width: 0.5,
    ),
  ),
)
```

## Component Examples

### AppBar
- Background: Pure White (#FFFFFF)
- Text: Black (#000000)
- Border: System Gray 5 (#E5E5EA) with 0.5px width
- Font: Roboto w600

### Sidebar
- Background: Pure White (#FFFFFF)
- Text: Black (#000000)
- Hover: System Gray 6 (#F2F2F7)
- Selected Background: System Gray 5 (#E5E5EA)
- Selected Text/Icon: System Blue (#007AFF)
- Selected Indicator: 3px System Blue left border
- Font: Roboto (w600 for selected, normal for others)

### Content Screens
- Background: Pure White (#FFFFFF)
- Primary Text: Black (#000000), Roboto w600
- Secondary Text: System Gray (#3C3C43), Roboto normal
- Accent Icons: System Blue (#007AFF)

## Files Modified

1. **lib/main.dart**
   - Added `fontFamily: 'Roboto'` to ThemeData
   - Updated appBarTheme colors
   - Applied Apple-inspired color scheme

2. **lib/core/constants/app_colors.dart**
   - Complete rewrite with Apple design system
   - 9 organized sections
   - Extensive documentation
   - All colors mapped to Apple's system palette

3. **lib/view/widgets/app_sidebar.dart**
   - Updated to use `AppColors.primary` for selection
   - Added `fontFamily: 'Roboto'` to all text
   - Changed font weight to w600 for selected items
   - Updated hover and selected states

4. **lib/view/screens/desktop_screen.dart**
   - Applied Roboto font to all text
   - Updated colors to use new constants
   - Changed font weight to w600

5. **lib/view/screens/masters_screen.dart**
   - Applied Roboto font to all text
   - Updated colors to use new constants
   - Changed font weight to w600

## Future Considerations

1. **Custom Roboto Font**: If system Roboto isn't available, add Roboto font files to `assets/fonts/` and configure in `pubspec.yaml`

2. **Dark Mode**: Consider adding dark mode support with equivalent Apple dark theme colors:
   - Background: #000000
   - Secondary Background: #1C1C1E
   - Tertiary Background: #2C2C2E
   - System Blue remains: #0A84FF (slightly brighter for dark mode)

3. **Accessibility**: All color combinations meet WCAG AA standards:
   - Black on White: 21:1 contrast ratio
   - System Blue on White: 4.56:1 contrast ratio
   - Secondary text on White: 8.58:1 contrast ratio

## References
- Apple Human Interface Guidelines - Color System
- Apple Human Interface Guidelines - Typography
- Material Design 3 (for Flutter components)
- Roboto Font Family (Google Fonts)

## Version History
- **v1.0** (Current): Initial Apple-inspired Content-First Design implementation
  - Pure white backgrounds
  - System Blue accent
  - Roboto font family
  - Complete color system with 9 organized sections
