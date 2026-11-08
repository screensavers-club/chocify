// Chocofi handwired: default keymap (QWERTY + 3 layers). Left outer thumb is Cmd (GUI).
// Hold both layer thumbs (SYM + NAV) to reach the ADJUST layer with QK_BOOT.
#include QMK_KEYBOARD_H

enum layers { BASE, SYM, NAV, ADJUST, MOUSE };

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
        QK_BOOT, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,           XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, QK_BOOT,
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
