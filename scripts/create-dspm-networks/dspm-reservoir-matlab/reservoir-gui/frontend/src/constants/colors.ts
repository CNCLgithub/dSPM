// Muted, sophisticated color definitions for port types

export const PORT_COLORS = {
  'ext-in': {
    primary: '#9F5858',    // muted rose
    muted: '#9F585880',
    subtle: '#9F585815',
    dot: '#9F5858',
    button: '#B87878',     // lighter, softer rose for buttons
    name: 'rose',
  },
  'ext-out': {
    primary: '#4A8F8A',    // sage teal
    muted: '#4A8F8A80',
    subtle: '#4A8F8A15',
    dot: '#4A8F8A',
    button: '#6AA8A3',     // lighter, softer teal for buttons
    name: 'teal',
  },
  'rec-in': {
    primary: '#4A5C7A',    // slate blue
    muted: '#4A5C7A80',
    subtle: '#4A5C7A15',
    dot: '#4A5C7A',
    button: '#6A7C9A',     // lighter, softer slate for buttons
    name: 'slate',
  },
  'rec-out': {
    primary: '#A68B4B',    // muted gold
    muted: '#A68B4B80',
    subtle: '#A68B4B15',
    dot: '#A68B4B',
    button: '#C4A96B',     // lighter, softer gold for buttons
    name: 'gold',
  },
} as const;

// Dark mode variants (slightly more luminous)
export const PORT_COLORS_DARK = {
  'ext-in': {
    primary: '#C07878',
    muted: '#C0787880',
    subtle: '#C0787820',
    dot: '#C07878',
    button: '#D09898',
  },
  'ext-out': {
    primary: '#6AB0A8',
    muted: '#6AB0A880',
    subtle: '#6AB0A820',
    dot: '#6AB0A8',
    button: '#8AC8C0',
  },
  'rec-in': {
    primary: '#7A92B8',
    muted: '#7A92B880',
    subtle: '#7A92B820',
    dot: '#7A92B8',
    button: '#9AAAC8',
  },
  'rec-out': {
    primary: '#C9A860',
    muted: '#C9A86080',
    subtle: '#C9A86020',
    dot: '#C9A860',
    button: '#D9C080',
  },
} as const;

export type PortColorKey = keyof typeof PORT_COLORS;
export type PortColorConfig = typeof PORT_COLORS[PortColorKey];
