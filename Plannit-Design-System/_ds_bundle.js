/* @ds-bundle: {"format":4,"namespace":"PlannitDesignSystem_ede968","components":[{"name":"AvailabilityBar","sourcePath":"components/calendar/AvailabilityBar.jsx"},{"name":"EventCard","sourcePath":"components/calendar/EventCard.jsx"},{"name":"MonthGrid","sourcePath":"components/calendar/MonthGrid.jsx"},{"name":"SlotCard","sourcePath":"components/calendar/SlotCard.jsx"},{"name":"Avatar","sourcePath":"components/core/Avatar.jsx"},{"name":"AvatarStack","sourcePath":"components/core/AvatarStack.jsx"},{"name":"Badge","sourcePath":"components/core/Badge.jsx"},{"name":"Button","sourcePath":"components/core/Button.jsx"},{"name":"Card","sourcePath":"components/core/Card.jsx"},{"name":"Icon","sourcePath":"components/core/Icon.jsx"},{"name":"IconButton","sourcePath":"components/core/IconButton.jsx"},{"name":"Tag","sourcePath":"components/core/Tag.jsx"},{"name":"EmptyState","sourcePath":"components/feedback/EmptyState.jsx"},{"name":"ProgressDots","sourcePath":"components/feedback/ProgressDots.jsx"},{"name":"Sheet","sourcePath":"components/feedback/Sheet.jsx"},{"name":"Toast","sourcePath":"components/feedback/Toast.jsx"},{"name":"Tooltip","sourcePath":"components/feedback/Tooltip.jsx"},{"name":"Checkbox","sourcePath":"components/forms/Checkbox.jsx"},{"name":"DayOfWeekPicker","sourcePath":"components/forms/DayOfWeekPicker.jsx"},{"name":"Input","sourcePath":"components/forms/Input.jsx"},{"name":"Radio","sourcePath":"components/forms/Radio.jsx"},{"name":"SegmentedControl","sourcePath":"components/forms/SegmentedControl.jsx"},{"name":"Select","sourcePath":"components/forms/Select.jsx"},{"name":"Switch","sourcePath":"components/forms/Switch.jsx"},{"name":"ListRow","sourcePath":"components/navigation/ListRow.jsx"},{"name":"NavBar","sourcePath":"components/navigation/NavBar.jsx"},{"name":"TabBar","sourcePath":"components/navigation/TabBar.jsx"}],"sourceHashes":{"components/calendar/AvailabilityBar.jsx":"15c2d51eb4be","components/calendar/EventCard.jsx":"fd37983aff87","components/calendar/MonthGrid.jsx":"992df64bd921","components/calendar/SlotCard.jsx":"3f2960963aa2","components/core/Avatar.jsx":"b041f3be9f1e","components/core/AvatarStack.jsx":"1cadeaabf435","components/core/Badge.jsx":"a72d805fe3cc","components/core/Button.jsx":"5a2855c28152","components/core/Card.jsx":"bb993a93cd53","components/core/Icon.jsx":"4820c7209f91","components/core/IconButton.jsx":"94c2cf55b960","components/core/Tag.jsx":"217278fa2802","components/feedback/EmptyState.jsx":"d0147f54a93a","components/feedback/ProgressDots.jsx":"e530e91e1888","components/feedback/Sheet.jsx":"d932847cdd60","components/feedback/Toast.jsx":"566d6d67006b","components/feedback/Tooltip.jsx":"b354a9dbb6c3","components/forms/Checkbox.jsx":"f41ec578ed77","components/forms/DayOfWeekPicker.jsx":"7e155cc1403e","components/forms/Input.jsx":"7a7e75a4475b","components/forms/Radio.jsx":"5a681b9453f0","components/forms/SegmentedControl.jsx":"0b5dc70574c1","components/forms/Select.jsx":"8dfd88cae3d5","components/forms/Switch.jsx":"3d9b15c7e59d","components/navigation/ListRow.jsx":"24cf35a667b7","components/navigation/NavBar.jsx":"457bb6f92881","components/navigation/TabBar.jsx":"35e3e35714bc","ui_kits/plannit-ios/App.jsx":"91750e073692","ui_kits/plannit-ios/CalendarScreen.jsx":"52f04ba81af7","ui_kits/plannit-ios/Chrome.jsx":"8568cf49c3f9","ui_kits/plannit-ios/GroupsScreen.jsx":"6dcb7fc56839","ui_kits/plannit-ios/Onboarding.jsx":"fb8bfbb0f55f","ui_kits/plannit-ios/PlansScreen.jsx":"30be31237718","ui_kits/plannit-ios/data.js":"3651e8dc32fb"},"inlinedExternals":[],"unexposedExports":[]} */

(() => {

const __ds_ns = (window.PlannitDesignSystem_ede968 = window.PlannitDesignSystem_ede968 || {});

const __ds_scope = {};

(__ds_ns.__errors = __ds_ns.__errors || []);

// components/calendar/AvailabilityBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function AvailabilityBar({
  name,
  blocks = [],
  from = 8,
  to = 22,
  height = 12,
  style,
  ...rest
}) {
  const span = to - from;
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      ...style
    }
  }), name ? /*#__PURE__*/React.createElement("span", {
    style: {
      width: 64,
      flex: 'none',
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, name) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      flex: 1,
      height,
      borderRadius: 'var(--r-pill)',
      background: 'var(--teal-100)',
      overflow: 'hidden'
    }
  }, blocks.map((b, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      position: 'absolute',
      top: 0,
      bottom: 0,
      left: (b.start - from) / span * 100 + '%',
      width: (b.end - b.start) / span * 100 + '%',
      background: 'var(--status-busy)'
    }
  }))));
}
Object.assign(__ds_scope, { AvailabilityBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/calendar/AvailabilityBar.jsx", error: String((e && e.message) || e) }); }

// components/calendar/MonthGrid.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const DOW = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
function MonthGrid({
  year = 2026,
  month = 7,
  selected = 16,
  marks = {},
  onSelect,
  style,
  ...rest
}) {
  const first = new Date(year, month, 1);
  const lead = (first.getDay() + 6) % 7;
  const days = new Date(year, month + 1, 0).getDate();
  const cells = [...Array(lead).fill(null), ...Array.from({
    length: days
  }, (_, i) => i + 1)];
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      ...style
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(7,1fr)',
      gap: 2,
      marginBottom: 6
    }
  }, DOW.map((d, i) => /*#__PURE__*/React.createElement("div", {
    key: i,
    style: {
      textAlign: 'center',
      font: 'var(--type-caption)',
      color: 'var(--text-faint)',
      letterSpacing: 'var(--track-caps)'
    }
  }, d))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'grid',
      gridTemplateColumns: 'repeat(7,1fr)',
      gap: 2
    }
  }, cells.map((d, i) => {
    if (!d) return /*#__PURE__*/React.createElement("span", {
      key: i
    });
    const on = d === selected,
      hues = marks[d] || [];
    return /*#__PURE__*/React.createElement("button", {
      key: i,
      type: "button",
      onClick: () => onSelect && onSelect(d),
      style: {
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 3,
        aspectRatio: '1 / 1.05',
        border: 'none',
        borderRadius: 'var(--r-md)',
        cursor: 'pointer',
        background: on ? 'var(--action-primary)' : 'transparent',
        color: on ? 'var(--white)' : 'var(--text-body)',
        font: 'var(--fw-semibold) var(--text-subhead)/1 var(--font-core)',
        fontVariantNumeric: 'tabular-nums',
        transition: 'var(--transition-control)'
      }
    }, d, /*#__PURE__*/React.createElement("span", {
      style: {
        display: 'flex',
        gap: 2,
        height: 5
      }
    }, hues.slice(0, 3).map((h, j) => /*#__PURE__*/React.createElement("span", {
      key: j,
      style: {
        width: 5,
        height: 5,
        borderRadius: 'var(--r-pill)',
        background: on ? 'rgba(255,255,255,.9)' : h
      }
    }))));
  })));
}
Object.assign(__ds_scope, { MonthGrid });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/calendar/MonthGrid.jsx", error: String((e && e.message) || e) }); }

// components/core/Avatar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const HUES = ['var(--hue-coral)', 'var(--hue-amber)', 'var(--hue-teal)', 'var(--hue-sky)', 'var(--hue-indigo)', 'var(--hue-rose)'];
function pick(name = '') {
  let n = 0;
  for (let i = 0; i < name.length; i++) n += name.charCodeAt(i);
  return HUES[n % HUES.length];
}
function Avatar({
  name = '',
  src,
  size = 40,
  ring,
  status,
  style,
  ...rest
}) {
  const initials = name.trim().split(/\s+/).slice(0, 2).map(w => w[0] || '').join('').toUpperCase();
  return /*#__PURE__*/React.createElement("span", _extends({}, rest, {
    style: {
      position: 'relative',
      display: 'inline-flex',
      flex: 'none',
      width: size,
      height: size,
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: '100%',
      height: '100%',
      borderRadius: 'var(--r-pill)',
      overflow: 'hidden',
      background: src ? 'var(--bg-sunk)' : pick(name),
      color: 'var(--white)',
      font: 'var(--fw-bold) ' + Math.round(size * 0.4) + 'px/1 var(--font-display)',
      boxShadow: ring ? '0 0 0 2px var(--bg-surface),0 0 0 4px ' + ring : 'none'
    }
  }, src ? /*#__PURE__*/React.createElement("img", {
    src: src,
    alt: name,
    style: {
      width: '100%',
      height: '100%',
      objectFit: 'cover'
    }
  }) : initials), status ? /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      right: -1,
      bottom: -1,
      width: Math.max(10, size * 0.28),
      height: Math.max(10, size * 0.28),
      borderRadius: 'var(--r-pill)',
      background: status === 'free' ? 'var(--status-free)' : 'var(--status-busy)',
      boxShadow: '0 0 0 2px var(--bg-surface)'
    }
  }) : null);
}
Object.assign(__ds_scope, { Avatar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Avatar.jsx", error: String((e && e.message) || e) }); }

// components/core/AvatarStack.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function AvatarStack({
  people = [],
  size = 32,
  max = 4,
  style,
  ...rest
}) {
  const shown = people.slice(0, max),
    extra = people.length - shown.length;
  return /*#__PURE__*/React.createElement("span", _extends({}, rest, {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      ...style
    }
  }), shown.map((p, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      marginLeft: i ? -size * 0.3 : 0,
      borderRadius: 'var(--r-pill)',
      boxShadow: '0 0 0 2px var(--bg-surface)',
      display: 'inline-flex'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Avatar, {
    name: p.name,
    src: p.src,
    size: size
  }))), extra > 0 ? /*#__PURE__*/React.createElement("span", {
    style: {
      marginLeft: -size * 0.3,
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: size,
      height: size,
      borderRadius: 'var(--r-pill)',
      background: 'var(--bg-sunk)',
      color: 'var(--text-muted)',
      font: 'var(--fw-bold) ' + Math.round(size * 0.36) + 'px/1 var(--font-core)',
      boxShadow: '0 0 0 2px var(--bg-surface)'
    }
  }, "+", extra) : null);
}
Object.assign(__ds_scope, { AvatarStack });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/AvatarStack.jsx", error: String((e && e.message) || e) }); }

// components/core/Card.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Card({
  elevation = 1,
  pad = 16,
  accent,
  onClick,
  children,
  style,
  ...rest
}) {
  const [press, setPress] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick,
    onPointerDown: () => onClick && setPress(true),
    onPointerUp: () => setPress(false),
    onPointerLeave: () => setPress(false),
    style: {
      position: 'relative',
      overflow: 'hidden',
      background: 'var(--bg-surface)',
      borderRadius: 'var(--r-card)',
      padding: pad,
      boxShadow: elevation === 0 ? 'var(--ring-inset)' : elevation === 1 ? 'var(--shadow-1),var(--ring-inset)' : elevation === 2 ? 'var(--shadow-2)' : 'var(--shadow-3)',
      cursor: onClick ? 'pointer' : 'default',
      transform: press ? 'scale(.988)' : 'none',
      transition: 'transform var(--dur-fast) var(--ease-out),box-shadow var(--dur-base) var(--ease-out)',
      ...style
    }
  }, rest), accent ? /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      left: 0,
      top: 0,
      bottom: 0,
      width: 4,
      background: accent
    }
  }) : null, children);
}
Object.assign(__ds_scope, { Card });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Card.jsx", error: String((e && e.message) || e) }); }

// components/core/Icon.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Icon({
  name,
  size = 20,
  color = 'currentColor',
  basePath,
  style,
  ...rest
}) {
  const base = basePath || typeof window !== 'undefined' && window.PLANNIT_ICON_BASE || 'assets/icons';
  const url = 'url("' + base + '/' + name + '.svg")';
  return /*#__PURE__*/React.createElement("span", _extends({
    "aria-hidden": "true"
  }, rest, {
    style: {
      display: 'inline-block',
      flex: 'none',
      width: size,
      height: size,
      backgroundColor: color,
      WebkitMaskImage: url,
      maskImage: url,
      WebkitMaskSize: 'contain',
      maskSize: 'contain',
      WebkitMaskRepeat: 'no-repeat',
      maskRepeat: 'no-repeat',
      WebkitMaskPosition: 'center',
      maskPosition: 'center',
      ...style
    }
  }));
}
Object.assign(__ds_scope, { Icon });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Icon.jsx", error: String((e && e.message) || e) }); }

// components/core/Badge.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const TONES = {
  neutral: ['var(--bg-sunk)', 'var(--text-muted)'],
  primary: ['var(--coral-50)', 'var(--coral-700)'],
  free: ['var(--teal-50)', 'var(--teal-700)'],
  warning: ['#FDF3E0', 'var(--amber-500)'],
  danger: ['var(--red-50)', 'var(--red-500)'],
  solid: ['var(--action-primary)', 'var(--white)']
};
function Badge({
  tone = 'neutral',
  icon,
  children,
  style,
  ...rest
}) {
  const [bg, fg] = TONES[tone] || TONES.neutral;
  return /*#__PURE__*/React.createElement("span", _extends({}, rest, {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 4,
      padding: '3px 8px',
      borderRadius: 'var(--r-pill)',
      background: bg,
      color: fg,
      font: 'var(--type-label)',
      letterSpacing: '.01em',
      whiteSpace: 'nowrap',
      ...style
    }
  }), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 12
  }) : null, children);
}
Object.assign(__ds_scope, { Badge });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Badge.jsx", error: String((e && e.message) || e) }); }

// components/calendar/EventCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function EventCard({
  title,
  time,
  location,
  hue = 'var(--hue-coral)',
  group,
  people,
  icon,
  badge,
  badgeTone = 'neutral',
  onClick,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement(__ds_scope.Card, _extends({
    elevation: 1,
    pad: 0,
    onClick: onClick,
    style: {
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 12,
      padding: '14px 16px 14px 14px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      width: 44,
      height: 44,
      borderRadius: 'var(--r-md)',
      background: hue
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon || 'calendar',
    size: 22,
    color: "var(--white)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      minWidth: 0,
      font: 'var(--type-headline)',
      color: 'var(--text-strong)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, title), badge ? /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    tone: badgeTone
  }, badge) : null), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      marginTop: 3,
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "clock",
    size: 13
  }), /*#__PURE__*/React.createElement("span", null, time), location ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("span", {
    style: {
      opacity: .5
    }
  }, "\xB7"), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "map-pin",
    size: 13
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, location)) : null), group || people ? /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 10
    }
  }, group ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 5,
      font: 'var(--type-caption)',
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 7,
      height: 7,
      borderRadius: 'var(--r-pill)',
      background: hue
    }
  }), group) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), people ? /*#__PURE__*/React.createElement(__ds_scope.AvatarStack, {
    people: people,
    size: 24,
    max: 4
  }) : null) : null)));
}
Object.assign(__ds_scope, { EventCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/calendar/EventCard.jsx", error: String((e && e.message) || e) }); }

// components/calendar/SlotCard.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function SlotCard({
  day,
  date,
  time,
  freeCount,
  total,
  people,
  best,
  selected,
  onClick,
  style,
  ...rest
}) {
  const all = freeCount === total;
  return /*#__PURE__*/React.createElement(__ds_scope.Card, _extends({
    elevation: selected ? 2 : 1,
    pad: 0,
    onClick: onClick,
    style: {
      boxShadow: selected ? 'var(--shadow-2),inset 0 0 0 2px var(--action-primary)' : undefined,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      padding: '14px 16px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      width: 52,
      padding: '6px 0',
      borderRadius: 'var(--r-md)',
      background: all ? 'var(--teal-50)' : 'var(--bg-sunk)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: all ? 'var(--teal-700)' : 'var(--text-muted)'
    }
  }, day), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--fw-heavy) var(--text-title2)/1.05 var(--font-display)',
      fontVariantNumeric: 'tabular-nums',
      color: all ? 'var(--teal-700)' : 'var(--text-strong)'
    }
  }, date)), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-headline)',
      color: 'var(--text-strong)'
    }
  }, time), best ? /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    tone: "primary",
    icon: "sparkles"
  }, "Best") : null), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      marginTop: 6
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Badge, {
    tone: all ? 'free' : 'neutral',
    icon: all ? 'check' : undefined
  }, freeCount, " of ", total, " free"), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), people ? /*#__PURE__*/React.createElement(__ds_scope.AvatarStack, {
    people: people,
    size: 24,
    max: 4
  }) : null)), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-right",
    size: 18,
    color: "var(--text-faint)"
  })));
}
Object.assign(__ds_scope, { SlotCard });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/calendar/SlotCard.jsx", error: String((e && e.message) || e) }); }

// components/core/Button.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const SIZES = {
  sm: {
    h: 36,
    px: 14,
    font: 'var(--type-subhead)',
    icon: 16,
    gap: 6
  },
  md: {
    h: 46,
    px: 18,
    font: 'var(--type-headline)',
    icon: 18,
    gap: 8
  },
  lg: {
    h: 54,
    px: 22,
    font: 'var(--fw-bold) var(--text-body-size)/1 var(--font-display)',
    icon: 20,
    gap: 10
  }
};
function Button({
  variant = 'primary',
  size = 'md',
  icon,
  iconAfter,
  fullWidth,
  disabled,
  loading,
  children,
  onClick,
  style,
  ...rest
}) {
  const [press, setPress] = React.useState(false);
  const s = SIZES[size] || SIZES.md;
  const skin = {
    primary: {
      background: press ? 'var(--action-primary-press)' : 'var(--action-primary)',
      color: 'var(--text-on-primary)',
      boxShadow: press ? 'none' : 'var(--shadow-primary)'
    },
    secondary: {
      background: press ? 'var(--action-secondary-press)' : 'var(--action-secondary)',
      color: 'var(--text-strong)'
    },
    outline: {
      background: press ? 'var(--bg-sunk)' : 'transparent',
      color: 'var(--text-strong)',
      boxShadow: 'inset 0 0 0 1.5px var(--line-strong)'
    },
    ghost: {
      background: press ? 'var(--bg-sunk)' : 'transparent',
      color: 'var(--text-link)'
    },
    free: {
      background: press ? 'var(--teal-600)' : 'var(--status-free)',
      color: 'var(--white)'
    },
    danger: {
      background: 'transparent',
      color: 'var(--status-danger)'
    }
  }[variant] || {};
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    disabled: disabled || loading,
    onClick: onClick,
    onPointerDown: () => setPress(true),
    onPointerUp: () => setPress(false),
    onPointerLeave: () => setPress(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      gap: s.gap,
      minHeight: s.h,
      padding: '0 ' + s.px + 'px',
      width: fullWidth ? '100%' : 'auto',
      border: 'none',
      borderRadius: 'var(--r-pill)',
      font: s.font,
      letterSpacing: 'var(--track-body)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .42 : 1,
      transform: press ? 'scale(var(--press-scale))' : 'none',
      transition: 'var(--transition-control)',
      WebkitTapHighlightColor: 'transparent',
      ...skin,
      ...style
    }
  }, rest), loading ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "hourglass",
    size: s.icon
  }) : icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: s.icon
  }) : null, children, iconAfter ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: iconAfter,
    size: s.icon
  }) : null);
}
Object.assign(__ds_scope, { Button });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Button.jsx", error: String((e && e.message) || e) }); }

// components/core/IconButton.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function IconButton({
  name,
  size = 44,
  iconSize,
  variant = 'plain',
  label,
  disabled,
  onClick,
  style,
  ...rest
}) {
  const [press, setPress] = React.useState(false);
  const skin = {
    plain: {
      background: 'transparent',
      color: 'var(--text-strong)'
    },
    filled: {
      background: press ? 'var(--action-secondary-press)' : 'var(--action-secondary)',
      color: 'var(--text-strong)'
    },
    primary: {
      background: press ? 'var(--action-primary-press)' : 'var(--action-primary)',
      color: 'var(--white)',
      boxShadow: press ? 'none' : 'var(--shadow-primary)'
    },
    chrome: {
      background: 'var(--bg-chrome)',
      backdropFilter: 'var(--blur-chrome)',
      color: 'var(--text-strong)',
      boxShadow: 'var(--ring-inset)'
    }
  }[variant] || {};
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    "aria-label": label,
    disabled: disabled,
    onClick: onClick,
    onPointerDown: () => setPress(true),
    onPointerUp: () => setPress(false),
    onPointerLeave: () => setPress(false),
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: size,
      height: size,
      flex: 'none',
      border: 'none',
      borderRadius: 'var(--r-pill)',
      cursor: 'pointer',
      opacity: disabled ? .4 : 1,
      transform: press ? 'scale(var(--press-scale))' : 'none',
      transition: 'var(--transition-control)',
      WebkitTapHighlightColor: 'transparent',
      ...skin,
      ...style
    }
  }, rest), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: name,
    size: iconSize || Math.round(size * 0.48)
  }));
}
Object.assign(__ds_scope, { IconButton });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/IconButton.jsx", error: String((e && e.message) || e) }); }

// components/core/Tag.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Tag({
  hue = 'var(--hue-coral)',
  soft,
  selected,
  icon,
  onClick,
  onRemove,
  children,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("span", _extends({
    onClick: onClick
  }, rest, {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6,
      minHeight: 32,
      padding: onRemove ? '0 6px 0 12px' : '0 12px',
      borderRadius: 'var(--r-chip)',
      cursor: onClick ? 'pointer' : 'default',
      background: selected ? hue : soft || 'var(--bg-sunk)',
      color: selected ? 'var(--white)' : 'var(--text-body)',
      font: 'var(--type-subhead)',
      fontWeight: 'var(--fw-semibold)',
      boxShadow: selected ? 'none' : 'inset 0 0 0 1px var(--line-hairline)',
      transition: 'var(--transition-control)',
      ...style
    }
  }), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 14,
    color: selected ? 'var(--white)' : hue
  }) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: 'var(--r-pill)',
      background: selected ? 'var(--white)' : hue
    }
  }), children, onRemove ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "x",
    size: 14,
    onClick: onRemove,
    style: {
      cursor: 'pointer',
      opacity: .6,
      marginLeft: 2
    }
  }) : null);
}
Object.assign(__ds_scope, { Tag });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/core/Tag.jsx", error: String((e && e.message) || e) }); }

// components/feedback/EmptyState.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function EmptyState({
  icon = 'calendar-days',
  title,
  body,
  action,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      display: 'flex',
      flexDirection: 'column',
      alignItems: 'center',
      textAlign: 'center',
      gap: 8,
      padding: '40px 28px',
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 64,
      height: 64,
      marginBottom: 4,
      borderRadius: 'var(--r-xl)',
      background: 'var(--bg-tint-primary)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 28,
    color: "var(--coral-500)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-title3)',
      color: 'var(--text-strong)'
    }
  }, title), body ? /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-subhead)',
      color: 'var(--text-muted)',
      maxWidth: 300,
      textWrap: 'pretty'
    }
  }, body) : null, action ? /*#__PURE__*/React.createElement("div", {
    style: {
      marginTop: 8
    }
  }, action) : null);
}
Object.assign(__ds_scope, { EmptyState });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/EmptyState.jsx", error: String((e && e.message) || e) }); }

// components/feedback/ProgressDots.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function ProgressDots({
  count = 3,
  index = 0,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      ...style
    }
  }), Array.from({
    length: count
  }).map((_, i) => /*#__PURE__*/React.createElement("span", {
    key: i,
    style: {
      height: 6,
      width: i === index ? 20 : 6,
      borderRadius: 'var(--r-pill)',
      background: i === index ? 'var(--action-primary)' : 'var(--ink-200)',
      transition: 'width var(--dur-base) var(--ease-ios),background-color var(--dur-base) var(--ease-out)'
    }
  })));
}
Object.assign(__ds_scope, { ProgressDots });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/ProgressDots.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Sheet.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Sheet({
  open = true,
  title,
  onClose,
  footer,
  children,
  style,
  ...rest
}) {
  if (!open) return null;
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      inset: 0,
      zIndex: 60,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'flex-end'
    }
  }, /*#__PURE__*/React.createElement("div", {
    onClick: onClose,
    style: {
      position: 'absolute',
      inset: 0,
      background: 'var(--bg-scrim)',
      animation: 'plannit-fade var(--dur-base) var(--ease-out)'
    }
  }), /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      position: 'relative',
      background: 'var(--bg-surface)',
      borderRadius: 'var(--r-sheet) var(--r-sheet) 0 0',
      boxShadow: 'var(--shadow-sheet)',
      paddingBottom: 'var(--safe-bottom)',
      maxHeight: '90%',
      display: 'flex',
      flexDirection: 'column',
      animation: 'plannit-sheet var(--dur-sheet) var(--ease-ios)',
      ...style
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      justifyContent: 'center',
      paddingTop: 8
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 36,
      height: 5,
      borderRadius: 'var(--r-pill)',
      background: 'var(--ink-200)'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 8,
      padding: '8px 12px 12px 20px'
    }
  }, /*#__PURE__*/React.createElement("h3", {
    style: {
      flex: 1,
      font: 'var(--type-title3)',
      color: 'var(--text-strong)'
    }
  }, title), onClose ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    name: "x",
    label: "Close",
    size: 36,
    variant: "filled",
    onClick: onClose
  }) : null), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      overflowY: 'auto',
      padding: '0 20px 16px'
    }
  }, children), footer ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '12px 20px 4px',
      borderTop: '1px solid var(--line-hairline)'
    }
  }, footer) : null));
}
Object.assign(__ds_scope, { Sheet });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Sheet.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Toast.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Toast({
  tone = 'neutral',
  icon,
  children,
  action,
  onAction,
  style,
  ...rest
}) {
  const fg = tone === 'free' ? 'var(--teal-700)' : tone === 'danger' ? 'var(--status-danger)' : 'var(--text-strong)';
  const bg = tone === 'free' ? 'var(--teal-50)' : tone === 'danger' ? 'var(--red-50)' : 'var(--bg-surface)';
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      padding: '12px 14px',
      background: bg,
      borderRadius: 'var(--r-card)',
      boxShadow: 'var(--shadow-3)',
      color: fg,
      font: 'var(--type-subhead)',
      animation: 'plannit-toast var(--dur-base) var(--ease-pop)',
      ...style
    }
  }), icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 18
  }) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }, children), action ? /*#__PURE__*/React.createElement("button", {
    type: "button",
    onClick: onAction,
    style: {
      border: 'none',
      background: 'transparent',
      color: 'var(--text-link)',
      font: 'var(--type-subhead)',
      fontWeight: 'var(--fw-bold)',
      cursor: 'pointer'
    }
  }, action) : null);
}
Object.assign(__ds_scope, { Toast });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Toast.jsx", error: String((e && e.message) || e) }); }

// components/feedback/Tooltip.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Tooltip({
  label,
  side = 'top',
  children,
  style,
  ...rest
}) {
  const [show, setShow] = React.useState(false);
  const pos = side === 'top' ? {
    bottom: 'calc(100% + 8px)',
    left: '50%',
    transform: 'translateX(-50%)'
  } : {
    top: 'calc(100% + 8px)',
    left: '50%',
    transform: 'translateX(-50%)'
  };
  return /*#__PURE__*/React.createElement("span", _extends({}, rest, {
    onPointerEnter: () => setShow(true),
    onPointerLeave: () => setShow(false),
    style: {
      position: 'relative',
      display: 'inline-flex',
      ...style
    }
  }), children, show ? /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      zIndex: 70,
      whiteSpace: 'nowrap',
      padding: '6px 10px',
      borderRadius: 'var(--r-sm)',
      background: 'var(--ink-900)',
      color: 'var(--white)',
      font: 'var(--type-footnote)',
      boxShadow: 'var(--shadow-2)',
      animation: 'plannit-fade var(--dur-fast) var(--ease-out)',
      ...pos
    }
  }, label) : null);
}
Object.assign(__ds_scope, { Tooltip });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/feedback/Tooltip.jsx", error: String((e && e.message) || e) }); }

// components/forms/Checkbox.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Checkbox({
  checked,
  onChange,
  label,
  sublabel,
  disabled,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", _extends({}, rest, {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      minHeight: 'var(--tap-min)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .45 : 1,
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      width: 24,
      height: 24,
      marginTop: 2,
      borderRadius: 'var(--r-xs)',
      background: checked ? 'var(--action-primary)' : 'var(--bg-surface)',
      boxShadow: checked ? 'none' : 'inset 0 0 0 1.5px var(--line-strong)',
      transition: 'background-color var(--dur-fast) var(--ease-out)'
    }
  }, checked ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "check",
    size: 16,
    color: "var(--white)"
  }) : null), /*#__PURE__*/React.createElement("input", {
    type: "checkbox",
    checked: !!checked,
    onChange: onChange,
    readOnly: !onChange,
    disabled: disabled,
    style: {
      position: 'absolute',
      opacity: 0,
      width: 0,
      height: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      paddingTop: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-body)',
      color: 'var(--text-strong)'
    }
  }, label), sublabel ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginTop: 2
    }
  }, sublabel) : null));
}
Object.assign(__ds_scope, { Checkbox });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Checkbox.jsx", error: String((e && e.message) || e) }); }

// components/forms/DayOfWeekPicker.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const DAYS = [{
  i: 0,
  short: 'Su',
  name: 'Sunday'
}, {
  i: 1,
  short: 'Mo',
  name: 'Monday'
}, {
  i: 2,
  short: 'Tu',
  name: 'Tuesday'
}, {
  i: 3,
  short: 'We',
  name: 'Wednesday'
}, {
  i: 4,
  short: 'Th',
  name: 'Thursday'
}, {
  i: 5,
  short: 'Fr',
  name: 'Friday'
}, {
  i: 6,
  short: 'Sa',
  name: 'Saturday'
}];
function DayOfWeekPicker({
  value = [0, 1, 2, 3, 4, 5, 6],
  onChange,
  style,
  ...rest
}) {
  const toggle = i => {
    if (!onChange) return;
    onChange(value.includes(i) ? value.filter(v => v !== i) : [...value, i].sort((a, b) => a - b));
  };
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      display: 'flex',
      gap: 5,
      ...style
    }
  }), DAYS.map(d => {
    const on = value.includes(d.i);
    return /*#__PURE__*/React.createElement("button", {
      key: d.i,
      type: "button",
      "aria-pressed": on,
      "aria-label": d.name,
      onClick: () => toggle(d.i),
      style: {
        flex: 1,
        minWidth: 0,
        minHeight: 46,
        border: 'none',
        cursor: 'pointer',
        borderRadius: 'var(--r-md)',
        background: on ? 'var(--action-primary)' : 'var(--bg-surface)',
        color: on ? 'var(--white)' : 'var(--text-faint)',
        boxShadow: on ? 'none' : 'inset 0 0 0 1px var(--line-strong)',
        font: 'var(--fw-semibold) var(--text-subhead)/1 var(--font-core)',
        transition: 'var(--transition-control)',
        WebkitTapHighlightColor: 'transparent'
      }
    }, d.short);
  }));
}
Object.assign(__ds_scope, { DayOfWeekPicker });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/DayOfWeekPicker.jsx", error: String((e && e.message) || e) }); }

// components/forms/Input.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Input({
  label,
  hint,
  error,
  icon,
  value,
  onChange,
  placeholder,
  type = 'text',
  multiline,
  rows = 3,
  style,
  ...rest
}) {
  const [focus, setFocus] = React.useState(false);
  const El = multiline ? 'textarea' : 'input';
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'block',
      ...style
    }
  }, label ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 6
    }
  }, label) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: multiline ? 'flex-start' : 'center',
      gap: 10,
      padding: multiline ? '12px 14px' : '0 14px',
      minHeight: 48,
      background: 'var(--bg-surface)',
      borderRadius: 'var(--r-control)',
      boxShadow: error ? 'inset 0 0 0 1.5px var(--status-danger)' : focus ? 'inset 0 0 0 1.5px var(--line-focus),var(--ring-focus)' : 'inset 0 0 0 1px var(--line-strong)',
      transition: 'box-shadow var(--dur-fast) var(--ease-out)'
    }
  }, icon ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 18,
    color: "var(--text-faint)",
    style: {
      marginTop: multiline ? 3 : 0
    }
  }) : null, /*#__PURE__*/React.createElement(El, _extends({
    type: type,
    value: value,
    onChange: onChange,
    placeholder: placeholder,
    rows: multiline ? rows : undefined,
    onFocus: () => setFocus(true),
    onBlur: () => setFocus(false)
  }, rest, {
    style: {
      flex: 1,
      minWidth: 0,
      border: 'none',
      outline: 'none',
      background: 'transparent',
      resize: multiline ? 'vertical' : undefined,
      color: 'var(--text-strong)',
      font: 'var(--type-body)',
      letterSpacing: 'var(--track-body)',
      padding: multiline ? 0 : '12px 0'
    }
  }))), hint || error ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-footnote)',
      color: error ? 'var(--status-danger)' : 'var(--text-muted)',
      marginTop: 6
    }
  }, error || hint) : null);
}
Object.assign(__ds_scope, { Input });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Input.jsx", error: String((e && e.message) || e) }); }

// components/forms/Radio.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Radio({
  checked,
  onChange,
  label,
  sublabel,
  disabled,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", _extends({}, rest, {
    style: {
      display: 'flex',
      alignItems: 'flex-start',
      gap: 12,
      minHeight: 'var(--tap-min)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .45 : 1,
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      width: 24,
      height: 24,
      marginTop: 2,
      borderRadius: 'var(--r-pill)',
      background: 'var(--bg-surface)',
      boxShadow: checked ? 'inset 0 0 0 7px var(--action-primary)' : 'inset 0 0 0 1.5px var(--line-strong)',
      transition: 'box-shadow var(--dur-fast) var(--ease-pop)'
    }
  }), /*#__PURE__*/React.createElement("input", {
    type: "radio",
    checked: !!checked,
    onChange: onChange,
    readOnly: !onChange,
    disabled: disabled,
    style: {
      position: 'absolute',
      opacity: 0,
      width: 0,
      height: 0
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      paddingTop: 2
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-body)',
      color: 'var(--text-strong)'
    }
  }, label), sublabel ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginTop: 2
    }
  }, sublabel) : null));
}
Object.assign(__ds_scope, { Radio });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Radio.jsx", error: String((e && e.message) || e) }); }

// components/forms/SegmentedControl.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function SegmentedControl({
  options = [],
  value,
  onChange,
  fullWidth = true,
  style,
  ...rest
}) {
  const items = options.map(o => typeof o === 'string' ? {
    value: o,
    label: o
  } : o);
  const i = Math.max(0, items.findIndex(o => o.value === value));
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      position: 'relative',
      display: 'flex',
      padding: 3,
      gap: 0,
      background: 'var(--bg-sunk)',
      borderRadius: 'var(--r-pill)',
      width: fullWidth ? '100%' : 'auto',
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 3,
      bottom: 3,
      left: 'calc(' + i * 100 / items.length + '% + 3px)',
      width: 'calc(' + 100 / items.length + '% - 6px)',
      background: 'var(--bg-surface)',
      borderRadius: 'var(--r-pill)',
      boxShadow: 'var(--shadow-1)',
      transition: 'left var(--dur-base) var(--ease-ios)'
    }
  }), items.map(o => /*#__PURE__*/React.createElement("button", {
    key: o.value,
    type: "button",
    onClick: () => onChange && onChange(o.value),
    style: {
      position: 'relative',
      flex: 1,
      minHeight: 38,
      border: 'none',
      background: 'transparent',
      cursor: 'pointer',
      color: o.value === value ? 'var(--text-strong)' : 'var(--text-muted)',
      font: 'var(--type-subhead)',
      fontWeight: 'var(--fw-semibold)',
      borderRadius: 'var(--r-pill)',
      transition: 'color var(--dur-fast) var(--ease-out)'
    }
  }, o.label)));
}
Object.assign(__ds_scope, { SegmentedControl });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/SegmentedControl.jsx", error: String((e && e.message) || e) }); }

// components/forms/Select.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Select({
  label,
  options = [],
  value,
  onChange,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("label", {
    style: {
      display: 'block',
      ...style
    }
  }, label ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'block',
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 6
    }
  }, label) : null, /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'relative',
      display: 'flex',
      alignItems: 'center',
      background: 'var(--bg-surface)',
      borderRadius: 'var(--r-control)',
      boxShadow: 'inset 0 0 0 1px var(--line-strong)'
    }
  }, /*#__PURE__*/React.createElement("select", _extends({
    value: value,
    onChange: onChange
  }, rest, {
    style: {
      appearance: 'none',
      WebkitAppearance: 'none',
      flex: 1,
      minHeight: 48,
      border: 'none',
      outline: 'none',
      background: 'transparent',
      padding: '0 40px 0 14px',
      color: 'var(--text-strong)',
      font: 'var(--type-body)',
      cursor: 'pointer'
    }
  }), options.map(o => {
    const v = typeof o === 'string' ? o : o.value,
      l = typeof o === 'string' ? o : o.label;
    return /*#__PURE__*/React.createElement("option", {
      key: v,
      value: v
    }, l);
  })), /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-down",
    size: 18,
    color: "var(--text-faint)",
    style: {
      position: 'absolute',
      right: 14,
      pointerEvents: 'none'
    }
  })));
}
Object.assign(__ds_scope, { Select });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Select.jsx", error: String((e && e.message) || e) }); }

// components/forms/Switch.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function Switch({
  checked,
  onChange,
  disabled,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("button", _extends({
    type: "button",
    role: "switch",
    "aria-checked": !!checked,
    disabled: disabled,
    onClick: () => onChange && onChange(!checked)
  }, rest, {
    style: {
      position: 'relative',
      flex: 'none',
      width: 52,
      height: 32,
      border: 'none',
      padding: 0,
      borderRadius: 'var(--r-pill)',
      background: checked ? 'var(--status-free)' : 'var(--ink-200)',
      cursor: disabled ? 'not-allowed' : 'pointer',
      opacity: disabled ? .45 : 1,
      transition: 'background-color var(--dur-base) var(--ease-ios)',
      ...style
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      position: 'absolute',
      top: 2,
      left: checked ? 22 : 2,
      width: 28,
      height: 28,
      borderRadius: 'var(--r-pill)',
      background: 'var(--white)',
      boxShadow: 'var(--shadow-2)',
      transition: 'left var(--dur-base) var(--ease-ios)'
    }
  }));
}
Object.assign(__ds_scope, { Switch });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/forms/Switch.jsx", error: String((e && e.message) || e) }); }

// components/navigation/ListRow.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function ListRow({
  icon,
  iconTint,
  leading,
  title,
  subtitle,
  value,
  right,
  chevron,
  onClick,
  danger,
  last,
  style,
  ...rest
}) {
  const [press, setPress] = React.useState(false);
  return /*#__PURE__*/React.createElement("div", _extends({
    onClick: onClick
  }, rest, {
    onPointerDown: () => onClick && setPress(true),
    onPointerUp: () => setPress(false),
    onPointerLeave: () => setPress(false),
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12,
      minHeight: 'var(--tap-min)',
      padding: '10px 16px',
      background: press ? 'var(--bg-sunk)' : 'transparent',
      cursor: onClick ? 'pointer' : 'default',
      boxShadow: last ? 'none' : 'inset 0 -1px 0 var(--line-hairline)',
      transition: 'background-color var(--dur-instant) linear',
      ...style
    }
  }), leading, icon ? /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      flex: 'none',
      width: 32,
      height: 32,
      borderRadius: 'var(--r-sm)',
      background: iconTint || 'var(--bg-sunk)'
    }
  }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: icon,
    size: 18,
    color: iconTint ? 'var(--white)' : 'var(--text-muted)'
  })) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-body)',
      color: danger ? 'var(--status-danger)' : 'var(--text-strong)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, title), subtitle ? /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginTop: 1
    }
  }, subtitle) : null), value ? /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-subhead)',
      color: 'var(--text-muted)'
    }
  }, value) : null, right, chevron ? /*#__PURE__*/React.createElement(__ds_scope.Icon, {
    name: "chevron-right",
    size: 18,
    color: "var(--text-faint)"
  }) : null);
}
Object.assign(__ds_scope, { ListRow });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/ListRow.jsx", error: String((e && e.message) || e) }); }

// components/navigation/NavBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function NavBar({
  title,
  subtitle,
  large,
  back,
  onBack,
  actions = [],
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      position: 'sticky',
      top: 0,
      zIndex: 20,
      background: 'var(--bg-chrome)',
      backdropFilter: 'var(--blur-chrome)',
      WebkitBackdropFilter: 'var(--blur-chrome)',
      borderBottom: '1px solid var(--line-hairline)',
      padding: '0 8px',
      ...style
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 4,
      minHeight: 'var(--nav-h)'
    }
  }, back ? /*#__PURE__*/React.createElement(__ds_scope.IconButton, {
    name: "chevron-left",
    label: "Back",
    onClick: onBack,
    size: 40
  }) : /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0,
      textAlign: large ? 'left' : 'center',
      paddingLeft: large ? 8 : 0
    }
  }, !large ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-headline)',
      color: 'var(--text-strong)',
      whiteSpace: 'nowrap',
      overflow: 'hidden',
      textOverflow: 'ellipsis'
    }
  }, title), subtitle ? /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-caption)',
      color: 'var(--text-muted)'
    }
  }, subtitle) : null) : null), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 2
    }
  }, actions.map((a, i) => /*#__PURE__*/React.createElement(__ds_scope.IconButton, _extends({
    key: i,
    size: 40
  }, a))), !actions.length ? /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8
    }
  }) : null)), large ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '2px 12px 12px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-display)',
      letterSpacing: 'var(--track-display)',
      color: 'var(--text-strong)'
    }
  }, title), subtitle ? /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-subhead)',
      color: 'var(--text-muted)',
      marginTop: 2
    }
  }, subtitle) : null) : null);
}
Object.assign(__ds_scope, { NavBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/NavBar.jsx", error: String((e && e.message) || e) }); }

// components/navigation/TabBar.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
function TabBar({
  tabs = [],
  value,
  onChange,
  safeArea = true,
  style,
  ...rest
}) {
  return /*#__PURE__*/React.createElement("div", _extends({}, rest, {
    style: {
      display: 'flex',
      alignItems: 'stretch',
      background: 'var(--bg-chrome)',
      backdropFilter: 'var(--blur-chrome)',
      WebkitBackdropFilter: 'var(--blur-chrome)',
      borderTop: '1px solid var(--line-hairline)',
      paddingBottom: safeArea ? 'var(--safe-bottom)' : 0,
      ...style
    }
  }), tabs.map(t => {
    const on = t.value === value;
    return /*#__PURE__*/React.createElement("button", {
      key: t.value,
      type: "button",
      onClick: () => onChange && onChange(t.value),
      style: {
        flex: 1,
        display: 'flex',
        flexDirection: 'column',
        alignItems: 'center',
        justifyContent: 'center',
        gap: 3,
        minHeight: 'var(--tabbar-h)',
        border: 'none',
        background: 'transparent',
        cursor: 'pointer',
        color: on ? 'var(--action-primary)' : 'var(--text-faint)',
        WebkitTapHighlightColor: 'transparent'
      }
    }, /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'relative'
      }
    }, /*#__PURE__*/React.createElement(__ds_scope.Icon, {
      name: t.icon,
      size: 24
    }), t.badge ? /*#__PURE__*/React.createElement("span", {
      style: {
        position: 'absolute',
        top: -2,
        right: -6,
        minWidth: 16,
        height: 16,
        padding: '0 4px',
        borderRadius: 'var(--r-pill)',
        background: 'var(--action-primary)',
        color: 'var(--white)',
        font: 'var(--fw-bold) 10px/16px var(--font-core)',
        textAlign: 'center'
      }
    }, t.badge) : null), /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--fw-semibold) 10px/1 var(--font-core)',
        letterSpacing: '.01em'
      }
    }, t.label));
  }));
}
Object.assign(__ds_scope, { TabBar });
})(); } catch (e) { __ds_ns.__errors.push({ path: "components/navigation/TabBar.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/App.jsx
try { (() => {
const {
  TabBar,
  Toast
} = window.PlannitDesignSystem_ede968;
const TABS = [{
  value: 'cal',
  label: 'Calendar',
  icon: 'calendar-days'
}, {
  value: 'groups',
  label: 'Groups',
  icon: 'users'
}, {
  value: 'plans',
  label: 'Plans',
  icon: 'sparkles',
  badge: 2
}, {
  value: 'you',
  label: 'You',
  icon: 'user'
}];
function App() {
  const [flow, setFlow] = React.useState('welcome'); // welcome | connect | app
  const [tab, setTab] = React.useState('cal');
  const [stack, setStack] = React.useState(null); // {type,payload}
  const [sheet, setSheet] = React.useState(null); // 'plan' | 'group'
  const [toast, setToast] = React.useState(null);
  React.useEffect(() => {
    if (!toast) return;
    const t = setTimeout(() => setToast(null), 3200);
    return () => clearTimeout(t);
  }, [toast]);
  if (flow === 'welcome') return /*#__PURE__*/React.createElement(Phone, null, /*#__PURE__*/React.createElement(Welcome, {
    onStart: () => setFlow('connect'),
    onSignIn: () => setFlow('app')
  }));
  if (flow === 'connect') return /*#__PURE__*/React.createElement(Phone, null, /*#__PURE__*/React.createElement(ConnectCalendar, {
    onDone: () => setFlow('app')
  }));
  let body;
  if (stack && stack.type === 'event') body = /*#__PURE__*/React.createElement(EventDetail, {
    event: stack.payload,
    onBack: () => setStack(null)
  });else if (stack && stack.type === 'group') body = /*#__PURE__*/React.createElement(GroupDetail, {
    group: stack.payload,
    onBack: () => setStack(null),
    onFindDate: () => setSheet('plan')
  });else if (stack && stack.type === 'plan') body = /*#__PURE__*/React.createElement(PlanDetail, {
    plan: stack.payload,
    onBack: () => setStack(null)
  });else if (tab === 'cal') body = /*#__PURE__*/React.createElement(CalendarScreen, {
    onOpenEvent: e => setStack({
      type: 'event',
      payload: e
    }),
    onNewPlan: () => setSheet('plan')
  });else if (tab === 'groups') body = /*#__PURE__*/React.createElement(GroupsScreen, {
    onOpenGroup: g => setStack({
      type: 'group',
      payload: g
    }),
    onNewGroup: () => setSheet('group')
  });else if (tab === 'plans') body = /*#__PURE__*/React.createElement(PlansScreen, {
    onOpenPlan: p => setStack({
      type: 'plan',
      payload: p
    }),
    onNewPlan: () => setSheet('plan')
  });else body = /*#__PURE__*/React.createElement(YouScreen, null);
  const rootTab = !stack;
  return /*#__PURE__*/React.createElement(Phone, null, body, rootTab && tab !== 'you' ? /*#__PURE__*/React.createElement(Fab, {
    onClick: () => setSheet(tab === 'groups' ? 'group' : 'plan')
  }) : null, rootTab ? /*#__PURE__*/React.createElement(TabBar, {
    tabs: TABS,
    value: tab,
    onChange: v => {
      setStack(null);
      setTab(v);
    }
  }) : null, /*#__PURE__*/React.createElement(NewPlanSheet, {
    open: sheet === 'plan',
    onClose: () => setSheet(null),
    onFound: (name, groupName) => {
      setTab('plans');
      setToast(name + ' sent to ' + groupName + ' — 4 have voted already');
    }
  }), /*#__PURE__*/React.createElement(NewGroupSheet, {
    open: sheet === 'group',
    onClose: () => setSheet(null)
  }), toast ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 16,
      right: 16,
      bottom: 'calc(var(--tabbar-h) + var(--safe-bottom) + 12px)',
      zIndex: 70
    }
  }, /*#__PURE__*/React.createElement(Toast, {
    tone: "free",
    icon: "circle-check"
  }, toast)) : null);
}
Object.assign(window, {
  App
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/App.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/CalendarScreen.jsx
try { (() => {
function _extends() { return _extends = Object.assign ? Object.assign.bind() : function (n) { for (var e = 1; e < arguments.length; e++) { var t = arguments[e]; for (var r in t) ({}).hasOwnProperty.call(t, r) && (n[r] = t[r]); } return n; }, _extends.apply(null, arguments); }
const {
  NavBar,
  SegmentedControl,
  MonthGrid,
  EventCard,
  Card,
  EmptyState,
  Button,
  Icon,
  Badge
} = window.PlannitDesignSystem_ede968;
const MONTH = ['January', 'February', 'March', 'April', 'May', 'June', 'July', 'August', 'September', 'October', 'November', 'December'];
function CalendarScreen({
  onOpenEvent,
  onNewPlan
}) {
  const D = window.PlannitData;
  const [view, setView] = React.useState('Month');
  const [day, setDay] = React.useState(16);
  const dayEvents = D.events.filter(e => e.day === day);
  const listEvents = view === 'List' ? D.events : dayEvents;
  const heading = view === 'List' ? 'Everything coming up' : 'Sat ' + day + ' August';
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    large: true,
    title: "August",
    subtitle: "4 plans this week",
    actions: [{
      name: 'search',
      label: 'Search'
    }, {
      name: 'bell',
      label: 'Notifications'
    }]
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '4px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(SegmentedControl, {
    options: ['Month', 'Week', 'List'],
    value: view,
    onChange: setView
  })), view !== 'List' ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 12,
    elevation: 1
  }, /*#__PURE__*/React.createElement(MonthGrid, {
    year: 2026,
    month: 7,
    selected: day,
    marks: D.marks,
    onSelect: setDay
  }))) : null, /*#__PURE__*/React.createElement(SectionLabel, {
    right: /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-faint)'
      }
    }, listEvents.length, " ", listEvents.length === 1 ? 'plan' : 'plans')
  }, heading), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--gap-list)',
      padding: '0 20px'
    }
  }, listEvents.length ? listEvents.map(e => /*#__PURE__*/React.createElement(EventCard, _extends({
    key: e.id
  }, e, {
    time: (view === 'List' ? 'Aug ' + e.day + ' · ' : '') + e.time,
    onClick: () => onOpenEvent(e)
  }))) : /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(EmptyState, {
    icon: "calendar-plus",
    title: "Nothing on this day",
    body: "Free all day. Want to see if the others are too?",
    action: /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      icon: "wand-sparkles",
      onClick: onNewPlan
    }, "Find a date")
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 14,
    elevation: 0,
    style: {
      background: 'var(--bg-tint-free)',
      boxShadow: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "repeat",
    size: 18,
    color: "var(--teal-700)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: 'var(--type-footnote)',
      color: 'var(--teal-700)'
    }
  }, "Synced with your iPhone calendar a moment ago")))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 120
    }
  })));
}
function EventDetail({
  event,
  onBack
}) {
  const e = event || {};
  const [sheet, setSheet] = React.useState(false);
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    back: true,
    title: e.title,
    subtitle: e.group ? e.group + ' · ' + (e.people ? e.people.length : 1) + ' going' : 'Only you',
    onBack: onBack,
    actions: [{
      name: 'pencil',
      label: 'Edit'
    }, {
      name: 'ellipsis',
      label: 'More'
    }]
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 20px 0'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      borderRadius: 'var(--r-xl)',
      background: e.hue || 'var(--hue-coral)',
      padding: '22px 20px',
      color: 'var(--white)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: e.icon || 'calendar',
    size: 28,
    color: "rgba(255,255,255,.9)"
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-title1)',
      letterSpacing: 'var(--track-title)',
      marginTop: 12
    }
  }, e.title), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-subhead)',
      opacity: .9,
      marginTop: 4
    }
  }, "Sat 16 August \xB7 ", e.time))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRowLike, {
    icon: "clock",
    title: "Saturday 16 August",
    value: e.time
  }), e.location ? /*#__PURE__*/React.createElement(ListRowLike, {
    icon: "map-pin",
    title: e.location,
    value: "Map"
  }) : null, /*#__PURE__*/React.createElement(ListRowLike, {
    icon: "lock",
    title: "Visible to",
    value: e.group ? e.group : 'Only you',
    last: true
  }))), e.people ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(SectionLabel, null, "Going"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, e.people.map((p, i) => /*#__PURE__*/React.createElement(PersonRow, {
    key: p.name,
    person: p,
    status: i % 3 === 2 ? 'busy' : 'free',
    last: i === e.people.length - 1
  }))))) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      padding: '20px'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "secondary",
    icon: "message-circle",
    fullWidth: true
  }, "Message"), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    icon: "share-2",
    fullWidth: true,
    onClick: () => setSheet(true)
  }, "Share")), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px 40px'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "danger",
    fullWidth: true
  }, "Remove from my calendar"))), /*#__PURE__*/React.createElement(ShareSheet, {
    open: sheet,
    onClose: () => setSheet(false),
    event: e
  }));
}
function ListRowLike({
  icon,
  title,
  value,
  last
}) {
  const {
    ListRow
  } = window.PlannitDesignSystem_ede968;
  return /*#__PURE__*/React.createElement(ListRow, {
    icon: icon,
    title: title,
    value: value,
    last: last
  });
}
function PersonRow({
  person,
  status,
  last
}) {
  const {
    ListRow,
    Avatar,
    Badge
  } = window.PlannitDesignSystem_ede968;
  return /*#__PURE__*/React.createElement(ListRow, {
    leading: /*#__PURE__*/React.createElement(Avatar, {
      name: person.name,
      size: 34,
      status: status
    }),
    title: person.name,
    right: /*#__PURE__*/React.createElement(Badge, {
      tone: status === 'free' ? 'free' : 'neutral'
    }, status === 'free' ? 'Free' : 'Busy'),
    last: last
  });
}
function ShareSheet({
  open,
  onClose,
  event
}) {
  const {
    Sheet,
    Checkbox,
    Button,
    Icon
  } = window.PlannitDesignSystem_ede968;
  const D = window.PlannitData;
  const [sel, setSel] = React.useState(['soccer']);
  const toggle = id => setSel(s => s.includes(id) ? s.filter(x => x !== id) : [...s, id]);
  return /*#__PURE__*/React.createElement(Sheet, {
    open: open,
    title: "Who can see this?",
    onClose: onClose,
    footer: /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      size: "lg",
      fullWidth: true,
      onClick: onClose
    }, "Share with ", sel.length, " ", sel.length === 1 ? 'group' : 'groups')
  }, /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginBottom: 12
    }
  }, "Everyone else keeps seeing a plain busy block \u2014 no title, no place."), D.groups.map(g => /*#__PURE__*/React.createElement("div", {
    key: g.id,
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement(Checkbox, {
    checked: sel.includes(g.id),
    onChange: () => toggle(g.id),
    label: g.name,
    sublabel: g.members.length + ' people',
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 10,
      height: 10,
      borderRadius: 'var(--r-pill)',
      background: g.hue
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      alignItems: 'center',
      marginTop: 8,
      padding: '12px 0',
      borderTop: '1px solid var(--line-hairline)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "link",
    size: 16,
    color: "var(--text-muted)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)'
    }
  }, "Or send a link \u2014 friends can reply without the app.")));
}
Object.assign(window, {
  CalendarScreen,
  EventDetail,
  ShareSheet
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/CalendarScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/Chrome.jsx
try { (() => {
const {
  IconButton
} = window.PlannitDesignSystem_ede968;
function StatusBar({
  dark
}) {
  const c = dark ? 'var(--white)' : 'var(--text-strong)';
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      justifyContent: 'space-between',
      height: 'var(--safe-top)',
      padding: '0 28px 6px',
      color: c,
      font: 'var(--fw-semibold) 14px/1 var(--font-core)',
      flex: 'none'
    }
  }, /*#__PURE__*/React.createElement("span", null, "9:41"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 5
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'flex-end',
      gap: 1.5
    }
  }, [4, 6, 8, 10].map(h => /*#__PURE__*/React.createElement("span", {
    key: h,
    style: {
      width: 3,
      height: h,
      borderRadius: 1,
      background: c
    }
  }))), /*#__PURE__*/React.createElement("span", {
    style: {
      width: 22,
      height: 11,
      borderRadius: 3,
      boxShadow: 'inset 0 0 0 1.2px ' + c,
      padding: 1.5,
      display: 'flex'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      borderRadius: 1.5,
      background: c
    }
  }))));
}
function Phone({
  children,
  dark
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'relative',
      width: 390,
      height: 844,
      flex: 'none',
      borderRadius: 44,
      overflow: 'hidden',
      background: dark ? 'var(--ink-900)' : 'var(--bg-app)',
      boxShadow: 'var(--shadow-3),0 0 0 10px #17140F,0 0 0 12px #2C2721',
      display: 'flex',
      flexDirection: 'column'
    }
  }, /*#__PURE__*/React.createElement(StatusBar, {
    dark: dark
  }), children, /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: '50%',
      bottom: 8,
      transform: 'translateX(-50%)',
      width: 134,
      height: 5,
      borderRadius: 'var(--r-pill)',
      background: dark ? 'rgba(255,255,255,.5)' : 'var(--ink-300)'
    }
  }));
}
function Screen({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minHeight: 0,
      display: 'flex',
      flexDirection: 'column',
      ...style
    }
  }, children);
}
function Scroll({
  children,
  style
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minHeight: 0,
      overflowY: 'auto',
      ...style
    }
  }, children);
}
function SectionLabel({
  children,
  right
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'baseline',
      gap: 8,
      padding: '18px 20px 8px'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-faint)'
    }
  }, children), right);
}
function Fab({
  onClick
}) {
  return /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      right: 20,
      bottom: 'calc(var(--tabbar-h) + var(--safe-bottom) + 16px)',
      zIndex: 30
    }
  }, /*#__PURE__*/React.createElement(IconButton, {
    name: "plus",
    variant: "primary",
    size: 58,
    iconSize: 26,
    label: "New plan",
    onClick: onClick
  }));
}
Object.assign(window, {
  StatusBar,
  Phone,
  Screen,
  Scroll,
  SectionLabel,
  Fab
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/Chrome.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/GroupsScreen.jsx
try { (() => {
const {
  NavBar,
  Card,
  ListRow,
  AvatarStack,
  Button,
  Badge,
  Icon,
  EmptyState,
  Input,
  Sheet,
  Tag
} = window.PlannitDesignSystem_ede968;
function GroupsScreen({
  onOpenGroup,
  onNewGroup
}) {
  const D = window.PlannitData;
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    large: true,
    title: "Groups",
    subtitle: "Who sees what",
    actions: [{
      name: 'user-plus',
      label: 'Add friend'
    }]
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement(SectionLabel, null, "Your groups"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--gap-list)',
      padding: '0 20px'
    }
  }, D.groups.map(g => /*#__PURE__*/React.createElement(Card, {
    key: g.id,
    pad: 14,
    elevation: 1,
    onClick: () => onOpenGroup(g)
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 12
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 44,
      height: 44,
      flex: 'none',
      borderRadius: 'var(--r-md)',
      background: g.hue
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "users",
    size: 22,
    color: "var(--white)"
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      minWidth: 0
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-headline)',
      color: 'var(--text-strong)'
    }
  }, g.name), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginTop: 2
    }
  }, g.note)), /*#__PURE__*/React.createElement(AvatarStack, {
    people: g.members,
    size: 26,
    max: 3
  }), /*#__PURE__*/React.createElement(Icon, {
    name: "chevron-right",
    size: 18,
    color: "var(--text-faint)"
  }))))), /*#__PURE__*/React.createElement(SectionLabel, null, "Friends not in a group yet"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "user",
    title: "Priya Nair",
    subtitle: "Joined last week",
    right: /*#__PURE__*/React.createElement(Button, {
      size: "sm",
      variant: "secondary",
      icon: "plus"
    }, "Add")
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "user",
    title: "Ben Alt",
    subtitle: "From your contacts",
    right: /*#__PURE__*/React.createElement(Button, {
      size: "sm",
      variant: "secondary",
      icon: "plus"
    }, "Add"),
    last: true
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "outline",
    size: "lg",
    fullWidth: true,
    icon: "plus",
    onClick: onNewGroup
  }, "Make a group")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 110
    }
  })));
}
function GroupDetail({
  group,
  onBack,
  onFindDate
}) {
  const g = group || window.PlannitData.groups[0];
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    back: true,
    title: g.name,
    subtitle: g.members.length + ' people',
    onBack: onBack,
    actions: [{
      name: 'settings',
      label: 'Group settings'
    }]
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '16px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 16,
    elevation: 1,
    style: {
      background: g.soft,
      boxShadow: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "wand-sparkles",
    size: 20,
    color: g.hue
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-headline)',
      color: 'var(--text-strong)'
    }
  }, "Find a date for ", g.name), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-body)',
      marginTop: 2
    }
  }, "Tell us roughly when \u2014 we\u2019ll do the rest."))), /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "md",
    fullWidth: true,
    icon: "sparkles",
    style: {
      marginTop: 12
    },
    onClick: onFindDate
  }, "Start a plan"))), /*#__PURE__*/React.createElement(SectionLabel, null, "Shared with this group"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "dumbbell",
    iconTint: g.hue,
    title: "Five-a-side",
    subtitle: "Sat 16 Aug \xB7 2:00 PM",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "calendar-check",
    iconTint: g.hue,
    title: "League match",
    subtitle: "Tue 26 Aug \xB7 7:00 PM",
    chevron: true,
    last: true
  }))), /*#__PURE__*/React.createElement(SectionLabel, null, "People"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, g.members.map((m, i) => /*#__PURE__*/React.createElement(MemberRow, {
    key: m.name,
    m: m,
    owner: i === 0,
    last: i === g.members.length - 1
  })))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "link",
    title: "Invite by link",
    subtitle: "Works without the app",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "trash-2",
    title: "Leave group",
    danger: true,
    last: true
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 40
    }
  })));
}
function MemberRow({
  m,
  owner,
  last
}) {
  const {
    ListRow,
    Avatar,
    Badge
  } = window.PlannitDesignSystem_ede968;
  return /*#__PURE__*/React.createElement(ListRow, {
    leading: /*#__PURE__*/React.createElement(Avatar, {
      name: m.name,
      size: 34
    }),
    title: m.name,
    right: owner ? /*#__PURE__*/React.createElement(Badge, {
      tone: "neutral"
    }, "Owner") : null,
    last: last
  });
}
function NewGroupSheet({
  open,
  onClose
}) {
  const [name, setName] = React.useState('');
  const [hue, setHue] = React.useState('var(--hue-teal)');
  const hues = ['var(--hue-coral)', 'var(--hue-amber)', 'var(--hue-teal)', 'var(--hue-sky)', 'var(--hue-indigo)', 'var(--hue-rose)'];
  return /*#__PURE__*/React.createElement(Sheet, {
    open: open,
    title: "Make a group",
    onClose: onClose,
    footer: /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      size: "lg",
      fullWidth: true,
      onClick: onClose
    }, "Create group")
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Group name",
    placeholder: "Sunday runs",
    value: name,
    onChange: e => setName(e.target.value),
    icon: "users",
    style: {
      marginBottom: 16
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 8
    }
  }, "Colour"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      marginBottom: 16
    }
  }, hues.map(h => /*#__PURE__*/React.createElement("button", {
    key: h,
    type: "button",
    onClick: () => setHue(h),
    style: {
      width: 38,
      height: 38,
      border: 'none',
      cursor: 'pointer',
      borderRadius: 'var(--r-pill)',
      background: h,
      boxShadow: hue === h ? '0 0 0 2px var(--bg-surface),0 0 0 4px ' + h : 'none'
    }
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 8
    }
  }, "Add people"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, ['Maya', 'Theo', 'Ada', 'Sam', 'Rae', 'Jo'].map((n, i) => /*#__PURE__*/React.createElement(Tag, {
    key: n,
    hue: hue,
    selected: i < 2
  }, n))));
}
Object.assign(window, {
  GroupsScreen,
  GroupDetail,
  NewGroupSheet
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/GroupsScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/Onboarding.jsx
try { (() => {
const {
  Button,
  ProgressDots,
  Icon,
  Card,
  Tag,
  Badge
} = window.PlannitDesignSystem_ede968;
const STEPS = [{
  icon: 'calendar-heart',
  title: 'One calendar,\nthe right people.',
  body: 'Plannit sits on top of the calendar already on your phone. Nothing moves, nothing gets rewritten.'
}, {
  icon: 'lock',
  title: 'Share a plan,\nnot your whole week.',
  body: 'Every event is private until you share it. Show five-a-side to Soccer, keep the dentist to yourself.'
}, {
  icon: 'wand-sparkles',
  title: 'Tap the days.\nWe find the time.',
  body: 'Pick a group, leave the days that could work switched on, and Plannit comes back with times everyone is actually free.'
}];
function Welcome({
  onStart,
  onSignIn
}) {
  const [i, setI] = React.useState(0);
  const s = STEPS[i];
  return /*#__PURE__*/React.createElement(Screen, {
    style: {
      padding: '0 28px 28px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'space-between',
      padding: '8px 0 0'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--fw-heavy) 22px/1 var(--font-display)',
      letterSpacing: 'var(--track-title)',
      color: 'var(--coral-600)'
    }
  }, "Plannit"), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    size: "sm",
    onClick: onSignIn
  }, "I have an account")), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      gap: 22
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 76,
      height: 76,
      borderRadius: 'var(--r-2xl)',
      background: 'var(--bg-tint-primary)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: s.icon,
    size: 34,
    color: "var(--coral-500)"
  })), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: 'var(--type-display)',
      letterSpacing: 'var(--track-display)',
      whiteSpace: 'pre-line',
      color: 'var(--text-strong)'
    }
  }, s.title), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body)',
      color: 'var(--text-muted)',
      textWrap: 'pretty',
      maxWidth: 300
    }
  }, s.body), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, i === 1 ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Tag, {
    hue: "var(--hue-teal)",
    selected: true
  }, "Soccer"), /*#__PURE__*/React.createElement(Tag, {
    hue: "var(--hue-amber)",
    soft: "var(--hue-amber-soft)"
  }, "Family"), /*#__PURE__*/React.createElement(Tag, {
    hue: "var(--hue-sky)",
    soft: "var(--hue-sky-soft)"
  }, "Work")) : null, i === 2 ? /*#__PURE__*/React.createElement(Card, {
    elevation: 1,
    pad: 12,
    style: {
      width: '100%'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "sparkles",
    size: 18,
    color: "var(--status-free)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: 'var(--type-subhead)',
      color: 'var(--text-strong)'
    }
  }, "Sat 16 Aug \xB7 2:00 PM"), /*#__PURE__*/React.createElement(Badge, {
    tone: "free",
    icon: "check"
  }, "6 of 6"))) : null)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 14
    }
  }, /*#__PURE__*/React.createElement(ProgressDots, {
    count: 3,
    index: i
  }), i < 2 ? /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg",
    fullWidth: true,
    iconAfter: "arrow-right",
    onClick: () => setI(i + 1)
  }, "Next") : /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg",
    fullWidth: true,
    icon: "apple",
    onClick: onStart
  }, "Continue with Apple"), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-faint)',
      textAlign: 'center'
    }
  }, i < 2 ? 'Takes about a minute to set up.' : 'We only read your calendar to work out when you’re free.')));
}
function ConnectCalendar({
  onDone
}) {
  const [state, setState] = React.useState('ask');
  return /*#__PURE__*/React.createElement(Screen, {
    style: {
      padding: '0 28px 28px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1,
      display: 'flex',
      flexDirection: 'column',
      justifyContent: 'center',
      gap: 20
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'flex',
      alignItems: 'center',
      justifyContent: 'center',
      width: 76,
      height: 76,
      borderRadius: 'var(--r-2xl)',
      background: state === 'done' ? 'var(--bg-tint-free)' : 'var(--bg-tint-primary)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: state === 'done' ? 'circle-check' : 'calendar-days',
    size: 34,
    color: state === 'done' ? 'var(--status-free)' : 'var(--coral-500)'
  })), /*#__PURE__*/React.createElement("h1", {
    style: {
      font: 'var(--type-title1)',
      letterSpacing: 'var(--track-title)',
      color: 'var(--text-strong)'
    }
  }, state === 'done' ? 'Your calendar is in.' : 'Add your iPhone calendar'), /*#__PURE__*/React.createElement("p", {
    style: {
      font: 'var(--type-body)',
      color: 'var(--text-muted)',
      textWrap: 'pretty'
    }
  }, state === 'done' ? 'Plannit made a calendar called “Plannit” for anything you plan here. Your existing events stay exactly where they are.' : 'Plannit reads your events so it knows when you’re busy, and writes new plans into a calendar of its own.'), /*#__PURE__*/React.createElement(Card, {
    pad: 14,
    elevation: 1
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      alignItems: 'flex-start'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "eye-off",
    size: 18,
    color: "var(--text-muted)",
    style: {
      marginTop: 2
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      textWrap: 'pretty'
    }
  }, "Nobody sees your event titles. When we look for a date, your friends only see grey blocks where you\u2019re busy.")))), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, state === 'ask' ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Button, {
    variant: "primary",
    size: "lg",
    fullWidth: true,
    onClick: () => setState('done')
  }, "Allow calendar access"), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    fullWidth: true,
    onClick: () => setState('done')
  }, "Maybe later")) : /*#__PURE__*/React.createElement(Button, {
    variant: "free",
    size: "lg",
    fullWidth: true,
    iconAfter: "arrow-right",
    onClick: onDone
  }, "Take me in")));
}
Object.assign(window, {
  Welcome,
  ConnectCalendar
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/Onboarding.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/PlansScreen.jsx
try { (() => {
const {
  NavBar,
  Card,
  SlotCard,
  AvailabilityBar,
  Badge,
  Button,
  Icon,
  Tag,
  Sheet,
  Input,
  Select,
  Checkbox,
  SegmentedControl,
  AvatarStack,
  Toast,
  EmptyState
} = window.PlannitDesignSystem_ede968;
function PlansScreen({
  onOpenPlan,
  onNewPlan
}) {
  const D = window.PlannitData;
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    large: true,
    title: "Plans",
    subtitle: "2 waiting on the group"
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement(SectionLabel, null, "Needs your vote"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--gap-list)',
      padding: '0 20px'
    }
  }, D.proposals.map(p => /*#__PURE__*/React.createElement(Card, {
    key: p.id,
    pad: 14,
    elevation: 1,
    onClick: () => onOpenPlan(p)
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 8,
      height: 8,
      borderRadius: 'var(--r-pill)',
      background: p.group.hue
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: 'var(--type-caption)',
      color: 'var(--text-muted)'
    }
  }, p.group.name), /*#__PURE__*/React.createElement(Badge, {
    tone: p.status === 'found' ? 'free' : 'warning',
    icon: p.status === 'found' ? 'check' : 'hourglass'
  }, p.status === 'found' ? 'Date found' : p.votes + ' of ' + p.group.members.length + ' voted')), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-title3)',
      color: 'var(--text-strong)',
      marginTop: 8
    }
  }, p.title), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 6,
      marginTop: 4,
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "wand-sparkles",
    size: 13
  }), /*#__PURE__*/React.createElement("span", null, p.constraint)), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10,
      marginTop: 12
    }
  }, /*#__PURE__*/React.createElement(AvatarStack, {
    people: p.group.members,
    size: 26,
    max: 4
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1
    }
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      font: 'var(--type-subhead)',
      fontWeight: 'var(--fw-semibold)',
      color: 'var(--text-link)'
    }
  }, p.status === 'found' ? 'See the date' : 'Pick a time'), /*#__PURE__*/React.createElement(Icon, {
    name: "chevron-right",
    size: 16,
    color: "var(--text-faint)"
  }))))), /*#__PURE__*/React.createElement(SectionLabel, null, "Past"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 14,
    elevation: 0
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 10
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "circle-check",
    size: 18,
    color: "var(--status-free)"
  }), /*#__PURE__*/React.createElement("span", {
    style: {
      flex: 1,
      font: 'var(--type-subhead)',
      color: 'var(--text-body)'
    }
  }, "Board games night \xB7 locked for Fri 8 Aug")))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "outline",
    size: "lg",
    fullWidth: true,
    icon: "wand-sparkles",
    onClick: onNewPlan
  }, "Find a date")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 110
    }
  })));
}
function PlanDetail({
  plan,
  onBack
}) {
  const p = plan || window.PlannitData.proposals[0];
  const [vote, setVote] = React.useState(0);
  const [locked, setLocked] = React.useState(false);
  const [tab, setTab] = React.useState('Slots');
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    back: true,
    title: p.title,
    subtitle: p.group.name + ' · ' + p.group.members.length + ' people',
    onBack: onBack,
    actions: [{
      name: 'ellipsis',
      label: 'More'
    }]
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 14,
    elevation: 0,
    style: {
      background: 'var(--bg-tint-primary)',
      boxShadow: 'none'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 10,
      alignItems: 'flex-start'
    }
  }, /*#__PURE__*/React.createElement(Icon, {
    name: "wand-sparkles",
    size: 18,
    color: "var(--coral-600)",
    style: {
      marginTop: 2
    }
  }), /*#__PURE__*/React.createElement("div", null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-subhead)',
      fontWeight: 'var(--fw-semibold)',
      color: 'var(--coral-700)'
    }
  }, "You asked for ", p.constraint), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--coral-700)',
      opacity: .85,
      marginTop: 2
    }
  }, "Three times work. Pick the one you like."))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '14px 20px 0'
    }
  }, /*#__PURE__*/React.createElement(SegmentedControl, {
    options: ['Slots', 'Who’s free'],
    value: tab,
    onChange: setTab
  })), tab === 'Slots' ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(SectionLabel, null, "Best times found"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 'var(--gap-list)',
      padding: '0 20px'
    }
  }, p.slots.map((s, i) => /*#__PURE__*/React.createElement(SlotCard, {
    key: i,
    day: s.day,
    date: s.date,
    time: s.time,
    freeCount: s.free,
    total: p.group.members.length,
    best: s.best,
    selected: vote === i,
    people: p.group.members.slice(0, s.free),
    onClick: () => setVote(i)
  })))) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(SectionLabel, {
    right: /*#__PURE__*/React.createElement("span", {
      style: {
        font: 'var(--type-caption)',
        color: 'var(--text-faint)'
      }
    }, "Sat 16 \xB7 8am\u201310pm")
  }, "Busy blocks only"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 14
  }, p.availability.map(a => /*#__PURE__*/React.createElement(AvailabilityBar, {
    key: a.name,
    name: a.name,
    blocks: a.blocks,
    style: {
      marginBottom: 10
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 14,
      marginTop: 4,
      font: 'var(--type-caption)',
      color: 'var(--text-muted)'
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 8,
      borderRadius: 4,
      background: 'var(--teal-100)'
    }
  }), "Free"), /*#__PURE__*/React.createElement("span", {
    style: {
      display: 'inline-flex',
      alignItems: 'center',
      gap: 6
    }
  }, /*#__PURE__*/React.createElement("span", {
    style: {
      width: 12,
      height: 8,
      borderRadius: 4,
      background: 'var(--status-busy)'
    }
  }), "Busy \u2014 titles never shared"))))), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px'
    }
  }, /*#__PURE__*/React.createElement(Button, {
    variant: "free",
    size: "lg",
    fullWidth: true,
    icon: "check",
    onClick: () => setLocked(true)
  }, "Lock in ", p.slots[vote].day.charAt(0) + p.slots[vote].day.slice(1).toLowerCase(), " ", p.slots[vote].date), /*#__PURE__*/React.createElement(Button, {
    variant: "ghost",
    fullWidth: true,
    style: {
      marginTop: 6
    }
  }, "None of these work")), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 20
    }
  })), locked ? /*#__PURE__*/React.createElement("div", {
    style: {
      position: 'absolute',
      left: 16,
      right: 16,
      bottom: 24,
      zIndex: 50
    }
  }, /*#__PURE__*/React.createElement(Toast, {
    tone: "free",
    icon: "circle-check",
    action: "Undo",
    onAction: () => setLocked(false)
  }, "On everyone\u2019s calendar. We\u2019ll nudge them.")) : null);
}
function NewPlanSheet({
  open,
  onClose,
  onFound
}) {
  const D = window.PlannitData;
  const SHORT = ['Sun', 'Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat'];
  const {
    DayOfWeekPicker,
    ListRow
  } = window.PlannitDesignSystem_ede968;
  const [step, setStep] = React.useState('ask');
  const [group, setGroup] = React.useState('soccer');
  const [newGroup, setNewGroup] = React.useState('');
  const [days, setDays] = React.useState([0, 1, 2, 3, 4, 5, 6]);
  const [times, setTimes] = React.useState(['Afternoon']);
  const [more, setMore] = React.useState(false);
  const [quorum, setQuorum] = React.useState(true);
  const [name, setName] = React.useState('');
  React.useEffect(() => {
    if (step === 'finding') {
      const t = setTimeout(() => setStep('found'), 1400);
      return () => clearTimeout(t);
    }
  }, [step]);
  React.useEffect(() => {
    if (!open) {
      setStep('ask');
      setName('');
    }
  }, [open]);
  const g = D.groups.find(x => x.id === group);
  const groupName = group === 'new' ? newGroup || 'your new group' : g.name;
  const dayText = days.length === 7 ? 'Any day' : days.map(d => SHORT[d]).join(', ');
  const timeText = times.length ? times.join(' or ').toLowerCase() : 'any time';
  const toggleTime = t => setTimes(s => s.includes(t) ? s.filter(x => x !== t) : [...s, t]);
  return /*#__PURE__*/React.createElement(Sheet, {
    open: open,
    onClose: onClose,
    title: step === 'found' ? 'Three times work' : step === 'finding' ? 'Checking calendars' : 'Find a date',
    footer: step === 'ask' ? /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      size: "lg",
      fullWidth: true,
      icon: "wand-sparkles",
      disabled: !days.length,
      onClick: () => setStep('finding')
    }, "Find a date") : step === 'finding' ? /*#__PURE__*/React.createElement(Button, {
      variant: "primary",
      size: "lg",
      fullWidth: true,
      loading: true,
      disabled: true
    }, "Checking ", group === 'new' ? 'their' : g.members.length + ' ', "calendars\u2026") : /*#__PURE__*/React.createElement(Button, {
      variant: "free",
      size: "lg",
      fullWidth: true,
      icon: "send",
      onClick: () => {
        onClose();
        onFound && onFound(name || 'Your plan', groupName);
      }
    }, "Send to ", groupName, " to vote")
  }, step === 'ask' ? /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 8
    }
  }, "Who\u2019s it with?"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap',
      marginBottom: group === 'new' ? 12 : 18
    }
  }, D.groups.map(x => /*#__PURE__*/React.createElement(Tag, {
    key: x.id,
    hue: x.hue,
    soft: x.soft,
    selected: group === x.id,
    onClick: () => setGroup(x.id)
  }, x.name)), /*#__PURE__*/React.createElement(Tag, {
    hue: "var(--text-muted)",
    icon: "plus",
    selected: group === 'new',
    onClick: () => setGroup('new')
  }, "New group")), group === 'new' ? /*#__PURE__*/React.createElement("div", {
    style: {
      marginBottom: 18
    }
  }, /*#__PURE__*/React.createElement(Input, {
    label: "Group name",
    placeholder: "Sunday runs",
    icon: "users",
    value: newGroup,
    onChange: e => setNewGroup(e.target.value),
    style: {
      marginBottom: 10
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap'
    }
  }, ['Maya', 'Theo', 'Ada', 'Sam', 'Rae', 'Jo'].map((n, i) => /*#__PURE__*/React.createElement(Tag, {
    key: n,
    hue: "var(--action-primary)",
    selected: i < 2
  }, n)))) : null, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 8
    }
  }, "Which days work?"), /*#__PURE__*/React.createElement(DayOfWeekPicker, {
    value: days,
    onChange: setDays
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      margin: '8px 0 16px'
    }
  }, days.length ? dayText + ' · ' + timeText + ' · next 3 weeks' : 'Tap at least one day.'), /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: more ? 'chevron-down' : 'chevron-right',
    title: "More details",
    subtitle: more ? null : 'Time of day, how long, who has to make it',
    onClick: () => setMore(!more),
    last: true
  }), more ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 16px 16px'
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-caption)',
      letterSpacing: 'var(--track-caps)',
      textTransform: 'uppercase',
      color: 'var(--text-muted)',
      marginBottom: 8
    }
  }, "Time of day"), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      gap: 8,
      flexWrap: 'wrap',
      marginBottom: 14
    }
  }, ['Morning', 'Afternoon', 'Evening'].map(t => /*#__PURE__*/React.createElement(Tag, {
    key: t,
    hue: "var(--action-primary)",
    selected: times.includes(t),
    onClick: () => toggleTime(t)
  }, t))), /*#__PURE__*/React.createElement(Select, {
    label: "How long?",
    options: ['1 hour', '2 hours', 'Half a day', 'All day'],
    style: {
      marginBottom: 12
    }
  }), /*#__PURE__*/React.createElement(Select, {
    label: "Look how far ahead?",
    options: ['Next 3 weeks', 'Next month', 'Next 3 months'],
    style: {
      marginBottom: 12
    }
  }), /*#__PURE__*/React.createElement(Checkbox, {
    checked: quorum,
    onChange: () => setQuorum(!quorum),
    label: "It\u2019s fine if one person can\u2019t make it",
    sublabel: "We\u2019ll accept 5 of 6 free"
  })) : null)) : step === 'finding' ? /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '20px 0'
    }
  }, D.proposals[0].availability.map((a, i) => /*#__PURE__*/React.createElement(AvailabilityBar, {
    key: a.name,
    name: a.name,
    blocks: a.blocks,
    style: {
      marginBottom: 10,
      opacity: 0,
      animation: 'plannit-fade var(--dur-base) var(--ease-out) ' + i * 140 + 'ms forwards'
    }
  })), /*#__PURE__*/React.createElement("div", {
    style: {
      textAlign: 'center',
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginTop: 10
    }
  }, "Looking at busy blocks, not your events.")) : /*#__PURE__*/React.createElement(React.Fragment, null, /*#__PURE__*/React.createElement(Input, {
    label: "Name this plan",
    placeholder: "Five-a-side",
    icon: "pencil",
    value: name,
    onChange: e => setName(e.target.value),
    style: {
      marginBottom: 16
    }
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginBottom: 12
    }
  }, dayText, " \xB7 ", timeText, ". Sorted by how many of you are free \u2014 send them all and let ", groupName, " vote."), /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      flexDirection: 'column',
      gap: 10
    }
  }, D.proposals[0].slots.map((s, i) => /*#__PURE__*/React.createElement(SlotCard, {
    key: i,
    day: s.day,
    date: s.date,
    time: s.time,
    freeCount: s.free,
    total: 6,
    best: s.best,
    people: (group === 'new' ? D.groups[0] : g).members.slice(0, s.free)
  })))));
}
function YouScreen() {
  const {
    ListRow,
    Avatar,
    Switch,
    Card,
    Button,
    Badge
  } = window.PlannitDesignSystem_ede968;
  const [sync, setSync] = React.useState(true);
  const [push, setPush] = React.useState(true);
  const [quiet, setQuiet] = React.useState(false);
  return /*#__PURE__*/React.createElement(Screen, null, /*#__PURE__*/React.createElement(NavBar, {
    large: true,
    title: "You"
  }), /*#__PURE__*/React.createElement(Scroll, null, /*#__PURE__*/React.createElement("div", {
    style: {
      display: 'flex',
      alignItems: 'center',
      gap: 14,
      padding: '6px 20px 18px'
    }
  }, /*#__PURE__*/React.createElement(Avatar, {
    name: "Chris Concho",
    size: 64
  }), /*#__PURE__*/React.createElement("div", {
    style: {
      flex: 1
    }
  }, /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-title3)',
      color: 'var(--text-strong)'
    }
  }, "Chris Concho"), /*#__PURE__*/React.createElement("div", {
    style: {
      font: 'var(--type-footnote)',
      color: 'var(--text-muted)',
      marginTop: 2
    }
  }, "Signed in with Apple \xB7 London")), /*#__PURE__*/React.createElement(Button, {
    size: "sm",
    variant: "secondary",
    icon: "pencil"
  }, "Edit")), /*#__PURE__*/React.createElement(SectionLabel, null, "Calendar"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "repeat",
    title: "Two-way sync",
    subtitle: "Synced a moment ago",
    right: /*#__PURE__*/React.createElement(Switch, {
      checked: sync,
      onChange: setSync
    })
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "calendar-days",
    title: "Plannit calendar",
    value: "On your iPhone",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "eye-off",
    title: "Availability sharing",
    subtitle: "Busy blocks only, no titles",
    right: /*#__PURE__*/React.createElement(Badge, {
      tone: "free"
    }, "On"),
    chevron: true,
    last: true
  }))), /*#__PURE__*/React.createElement(SectionLabel, null, "Notifications"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "bell",
    title: "New plans and votes",
    right: /*#__PURE__*/React.createElement(Switch, {
      checked: push,
      onChange: setPush
    })
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "moon",
    title: "Quiet hours",
    subtitle: "10pm \u2013 8am",
    right: /*#__PURE__*/React.createElement(Switch, {
      checked: quiet,
      onChange: setQuiet
    }),
    last: true
  }))), /*#__PURE__*/React.createElement(SectionLabel, null, "Plannit"), /*#__PURE__*/React.createElement("div", {
    style: {
      padding: '0 20px'
    }
  }, /*#__PURE__*/React.createElement(Card, {
    pad: 0
  }, /*#__PURE__*/React.createElement(ListRow, {
    icon: "link",
    title: "Invite a friend",
    subtitle: "No referral wall, ever",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "lock",
    title: "Privacy",
    chevron: true
  }), /*#__PURE__*/React.createElement(ListRow, {
    icon: "info",
    title: "About",
    value: "1.0 (beta)",
    last: true
  }))), /*#__PURE__*/React.createElement("div", {
    style: {
      height: 120
    }
  })));
}
Object.assign(window, {
  PlansScreen,
  PlanDetail,
  NewPlanSheet,
  YouScreen
});
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/PlansScreen.jsx", error: String((e && e.message) || e) }); }

// ui_kits/plannit-ios/data.js
try { (() => {
window.PlannitData = function () {
  const P = {
    maya: {
      name: 'Maya Ellis'
    },
    theo: {
      name: 'Theo Sand'
    },
    ada: {
      name: 'Ada Kim'
    },
    sam: {
      name: 'Sam Roe'
    },
    rae: {
      name: 'Rae Loft'
    },
    jo: {
      name: 'Jo Vane'
    }
  };
  const groups = [{
    id: 'soccer',
    name: 'Soccer',
    hue: 'var(--hue-teal)',
    soft: 'var(--hue-teal-soft)',
    members: [P.maya, P.theo, P.ada, P.sam, P.rae, P.jo],
    note: 'Tuesday + weekend games'
  }, {
    id: 'family',
    name: 'Family',
    hue: 'var(--hue-amber)',
    soft: 'var(--hue-amber-soft)',
    members: [P.maya, P.ada, P.rae],
    note: 'Birthdays and Sunday lunch'
  }, {
    id: 'work',
    name: 'Work',
    hue: 'var(--hue-sky)',
    soft: 'var(--hue-sky-soft)',
    members: [P.theo, P.sam, P.jo, P.ada],
    note: 'Offsites only, nothing else'
  }, {
    id: 'flat',
    name: 'Flatmates',
    hue: 'var(--hue-indigo)',
    soft: 'var(--hue-indigo-soft)',
    members: [P.sam, P.rae],
    note: 'Bills, bins, film nights'
  }];
  const events = [{
    id: 'e1',
    day: 16,
    title: 'Five-a-side',
    time: '2:00–4:00 PM',
    location: 'Hackney Marshes',
    group: 'Soccer',
    hue: 'var(--hue-teal)',
    icon: 'dumbbell',
    people: [P.maya, P.theo, P.ada, P.sam, P.rae, P.jo],
    badge: 'Found',
    badgeTone: 'free',
    source: 'plannit'
  }, {
    id: 'e2',
    day: 16,
    title: 'Dinner with Ada',
    time: '7:30 PM',
    location: 'Bermondsey',
    hue: 'var(--hue-coral)',
    icon: 'utensils',
    badge: 'Private',
    badgeTone: 'neutral',
    source: 'device'
  }, {
    id: 'e3',
    day: 17,
    title: "Mum's birthday lunch",
    time: '1:00 PM',
    location: 'Hers',
    group: 'Family',
    hue: 'var(--hue-amber)',
    icon: 'cake',
    people: [P.maya, P.ada, P.rae],
    source: 'plannit'
  }, {
    id: 'e4',
    day: 18,
    title: 'Film night',
    time: '8:00 PM',
    location: 'The flat',
    group: 'Flatmates',
    hue: 'var(--hue-indigo)',
    icon: 'film',
    people: [P.sam, P.rae],
    source: 'plannit'
  }, {
    id: 'e5',
    day: 20,
    title: 'Dentist',
    time: '9:15 AM',
    hue: 'var(--hue-coral)',
    icon: 'clock',
    badge: 'Private',
    badgeTone: 'neutral',
    source: 'device'
  }];
  const marks = {
    5: ['var(--hue-amber)'],
    9: ['var(--hue-rose)'],
    14: ['var(--hue-sky)', 'var(--hue-amber)'],
    16: ['var(--hue-teal)', 'var(--hue-coral)'],
    17: ['var(--hue-amber)'],
    18: ['var(--hue-indigo)'],
    20: ['var(--hue-coral)'],
    27: ['var(--hue-teal)']
  };
  const proposals = [{
    id: 'p1',
    title: 'Five-a-side',
    group: groups[0],
    constraint: 'Sat, Sun · afternoon · 2 hours',
    status: 'voting',
    votes: 4,
    slots: [{
      day: 'SAT',
      date: 16,
      time: '2:00 – 4:00 PM',
      free: 6,
      best: true
    }, {
      day: 'SUN',
      date: 17,
      time: '11:00 AM – 1:00 PM',
      free: 5
    }, {
      day: 'SAT',
      date: 23,
      time: '3:00 – 5:00 PM',
      free: 5
    }],
    availability: [{
      name: 'Maya',
      blocks: [{
        start: 9,
        end: 11
      }]
    }, {
      name: 'Theo',
      blocks: [{
        start: 8,
        end: 9
      }, {
        start: 18,
        end: 21
      }]
    }, {
      name: 'Ada',
      blocks: [{
        start: 13,
        end: 14
      }]
    }, {
      name: 'Sam',
      blocks: []
    }, {
      name: 'Rae',
      blocks: [{
        start: 19,
        end: 22
      }]
    }, {
      name: 'Jo',
      blocks: [{
        start: 8,
        end: 10
      }]
    }]
  }, {
    id: 'p2',
    title: 'Someone’s 30th',
    group: groups[1],
    constraint: 'Fri, Sat · evening · next 3 months',
    status: 'found',
    slots: [{
      day: 'SAT',
      date: 6,
      time: '7:00 PM',
      free: 3,
      best: true
    }],
    votes: 3,
    availability: []
  }];
  return {
    P,
    groups,
    events,
    marks,
    proposals,
    people: P
  };
}();
})(); } catch (e) { __ds_ns.__errors.push({ path: "ui_kits/plannit-ios/data.js", error: String((e && e.message) || e) }); }

__ds_ns.AvailabilityBar = __ds_scope.AvailabilityBar;

__ds_ns.EventCard = __ds_scope.EventCard;

__ds_ns.MonthGrid = __ds_scope.MonthGrid;

__ds_ns.SlotCard = __ds_scope.SlotCard;

__ds_ns.Avatar = __ds_scope.Avatar;

__ds_ns.AvatarStack = __ds_scope.AvatarStack;

__ds_ns.Badge = __ds_scope.Badge;

__ds_ns.Button = __ds_scope.Button;

__ds_ns.Card = __ds_scope.Card;

__ds_ns.Icon = __ds_scope.Icon;

__ds_ns.IconButton = __ds_scope.IconButton;

__ds_ns.Tag = __ds_scope.Tag;

__ds_ns.EmptyState = __ds_scope.EmptyState;

__ds_ns.ProgressDots = __ds_scope.ProgressDots;

__ds_ns.Sheet = __ds_scope.Sheet;

__ds_ns.Toast = __ds_scope.Toast;

__ds_ns.Tooltip = __ds_scope.Tooltip;

__ds_ns.Checkbox = __ds_scope.Checkbox;

__ds_ns.DayOfWeekPicker = __ds_scope.DayOfWeekPicker;

__ds_ns.Input = __ds_scope.Input;

__ds_ns.Radio = __ds_scope.Radio;

__ds_ns.SegmentedControl = __ds_scope.SegmentedControl;

__ds_ns.Select = __ds_scope.Select;

__ds_ns.Switch = __ds_scope.Switch;

__ds_ns.ListRow = __ds_scope.ListRow;

__ds_ns.NavBar = __ds_scope.NavBar;

__ds_ns.TabBar = __ds_scope.TabBar;

})();
