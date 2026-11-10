// Chocofi handwired: default keymap (QWERTY + 3 layers). Left outer thumb is Cmd (GUI).
// Hold both layer thumbs (SYM + NAV) to reach the ADJUST layer with QK_BOOT.
#include QMK_KEYBOARD_H
#include "raw_hid.h"

enum layers { BASE, SYM, NAV, ADJUST, MOUSE };
enum custom_keycodes { SIG_TOG = SAFE_RANGE };   // ADJUST + I: toggle iPad signal keys

// Right dotted thumb: tap for Backspace, hold for the MOUSE layer
#define BSP_MS LT(MOUSE, KC_BSPC)

// One-shot modifiers on the NAV home row: tap one, release NAV, then tap a letter
// (e.g. NAV + D, then C = Ctrl+C). Held down, they work as normal modifiers.
#define OS_GUI OSM(MOD_LGUI)
#define OS_ALT OSM(MOD_LALT)
#define OS_CTL OSM(MOD_LCTL)
#define OS_SFT OSM(MOD_LSFT)

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [BASE] = LAYOUT_split_3x5_3(
        KC_Q,         KC_W,    KC_E,    KC_R,    KC_T,         KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,
        KC_A,         KC_S,    KC_D,    KC_F,    KC_G,         KC_H,    KC_J,    KC_K,    KC_L,    KC_SCLN,
        LSFT_T(KC_Z), KC_X,    KC_C,    KC_V,    KC_B,         KC_N,    KC_M,    KC_COMM, KC_DOT,  RSFT_T(KC_SLSH),
                               KC_LGUI, MO(SYM), KC_SPC,       KC_ENT,  MO(NAV), BSP_MS
    ),
    [SYM] = LAYOUT_split_3x5_3(
        KC_1,    KC_2,    KC_3,    KC_4,    KC_5,              KC_6,    KC_7,    KC_8,    KC_9,    KC_0,
        KC_EXLM, KC_AT,   KC_HASH, KC_DLR,  KC_PERC,           KC_CIRC, KC_AMPR, KC_ASTR, KC_LPRN, KC_RPRN,
        KC_GRV,  KC_TILD, KC_BSLS, KC_PIPE, KC_MINS,           KC_EQL,  KC_PLUS, KC_LBRC, KC_RBRC, KC_QUOT,
                          _______, _______, _______,           _______, _______, KC_DEL
    ),
    [NAV] = LAYOUT_split_3x5_3(
        KC_ESC,  KC_TAB,  KC_CAPS, XXXXXXX, XXXXXXX,           KC_PGUP, KC_HOME, KC_UP,   KC_END,  KC_DEL,
        OS_GUI,  OS_ALT,  OS_CTL,  OS_SFT,  XXXXXXX,           KC_PGDN, KC_LEFT, KC_DOWN, KC_RGHT, KC_BSPC,
        KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,             KC_F6,   KC_F7,   KC_F8,   KC_F9,   KC_F10,
                          _______, _______, _______,           _______, _______, _______
    ),
    [ADJUST] = LAYOUT_split_3x5_3(
        QK_BOOT, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,           XXXXXXX, XXXXXXX, SIG_TOG, XXXXXXX, QK_BOOT,
        KC_F11,  KC_F12,  XXXXXXX, XXXXXXX, XXXXXXX,           KC_MPRV, KC_VOLD, KC_VOLU, KC_MNXT, KC_MPLY,
        XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,           XXXXXXX, KC_MUTE, XXXXXXX, XXXXXXX, XXXXXXX,
                          _______, _______, _______,           _______, _______, _______
    ),
    // Hold the right dotted thumb. Right hand moves and scrolls (same shape as the NAV arrows),
    // left hand clicks. Hold A for slow, precise movement. Cmd thumb still works for Cmd-click.
    [MOUSE] = LAYOUT_split_3x5_3(
        XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,           MS_WHLU, MS_WHLL, MS_UP,   MS_WHLR, XXXXXXX,
        MS_ACL0, MS_BTN3, MS_BTN2, MS_BTN1, XXXXXXX,           MS_WHLD, MS_LEFT, MS_DOWN, MS_RGHT, XXXXXXX,
        KC_LSFT, KC_LALT, KC_LCTL, XXXXXXX, XXXXXXX,           XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,
                          _______, MS_BTN2, MS_BTN1,           XXXXXXX, XXXXXXX, _______
    )
};

// Permissive hold everywhere except the Backspace/mouse key, so a fast Backspace-then-letter
// still types instead of jumping into the mouse layer.
bool get_permissive_hold(uint16_t keycode, keyrecord_t *record) {
    return keycode != BSP_MS;
}

layer_state_t layer_state_set_user(layer_state_t state) {
    return update_tri_layer_state(state, SYM, NAV, ADJUST);
}

// ---- State reporting ----
// Mac (tools/chocofi-hud): over raw HID (usage page 0xFF60, usage 0x61) the left half sends a
// 32-byte report whenever the active layer, armed one-shot mods, held mods or Caps Lock change:
//   [0] 0xC0 marker  [1] highest active layer  [2] one-shot mods  [3] held mods  [4] Caps Lock
// The HUD sends a report starting with 0xC0 to ask for the current state. Reports are 32 bytes on AVR.
//
// iPad (tools/chocofi-code-ios): iPadOS apps can't read raw HID, so the keyboard taps unused
// F-keys instead, which the app reads while it's in front and other apps ignore:
//   F13-F17 layer 0-4   F18 one-shots cleared   F19 F20 F21 F22 one-shot Cmd Alt Ctrl Shift armed
// On when the host looks like iOS/iPadOS; ADJUST + I toggles it; a HUD request turns it off.
static uint8_t last_state[4] = {0xFF, 0xFF, 0xFF, 0xFF};
static bool    state_requested = false;
static bool    signals_on      = false;
static bool    signals_decided = false;

static void signal_tap(uint8_t kc) {
    // tapping a key would use up an armed one-shot mod, so park them around the tap
    uint8_t os = get_oneshot_mods();
    if (os) clear_oneshot_mods();
    tap_code(kc);
    if (os) set_oneshot_mods(os);
}

static void send_signals(uint8_t layer, uint8_t os) {
    signal_tap(KC_F13 + (layer > 4 ? 0 : layer));
    signal_tap(KC_F18);
    if (os & MOD_MASK_GUI)   signal_tap(KC_F19);
    if (os & MOD_MASK_ALT)   signal_tap(KC_F20);
    if (os & MOD_MASK_CTRL)  signal_tap(KC_F21);
    if (os & MOD_MASK_SHIFT) signal_tap(KC_F22);
}

void housekeeping_task_user(void) {
    if (!is_keyboard_master()) return;
    if (!signals_decided && timer_read32() > 1500) {   // USB enumeration has finished by now
        signals_decided = true;
        if (detected_host_os() == OS_IOS) signals_on = true;
    }
    uint8_t now[4] = {get_highest_layer(layer_state), get_oneshot_mods(), get_mods(), host_keyboard_led_state().caps_lock};
    bool changed = memcmp(now, last_state, sizeof now) != 0;
    if (!state_requested && !changed) return;
    bool signal = signals_on && (now[0] != last_state[0] || now[1] != last_state[1]);
    memcpy(last_state, now, sizeof now);
    state_requested = false;
    uint8_t report[32] = {0};
    report[0] = 0xC0;
    memcpy(report + 1, now, sizeof now);
    raw_hid_send(report, 32);
    if (signal) send_signals(now[0], now[1]);
}

void raw_hid_receive(uint8_t *data, uint8_t length) {
    if (length > 0 && data[0] == 0xC0) {
        state_requested = true;
        signals_on = false;   // the Mac HUD is listening; no F-keys needed
        signals_decided = true;
    }
}

bool process_record_user(uint16_t keycode, keyrecord_t *record) {
    if (keycode == SIG_TOG && record->event.pressed) {
        signals_on = !signals_on;
        signals_decided = true;
        if (signals_on) send_signals(get_highest_layer(layer_state), get_oneshot_mods());
        return false;
    }
    return true;
}
