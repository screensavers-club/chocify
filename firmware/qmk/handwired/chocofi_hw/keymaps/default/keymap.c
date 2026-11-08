// Chocofi handwired: default keymap (QWERTY + 3 layers).
// Hold both layer thumbs (SYM + NAV) to reach the ADJUST layer with QK_BOOT.
#include QMK_KEYBOARD_H

enum layers { BASE, SYM, NAV, ADJUST };

const uint16_t PROGMEM keymaps[][MATRIX_ROWS][MATRIX_COLS] = {
    [BASE] = LAYOUT_split_3x5_3(
        KC_Q,         KC_W,    KC_E,    KC_R,    KC_T,         KC_Y,    KC_U,    KC_I,    KC_O,    KC_P,
        KC_A,         KC_S,    KC_D,    KC_F,    KC_G,         KC_H,    KC_J,    KC_K,    KC_L,    KC_SCLN,
        LSFT_T(KC_Z), KC_X,    KC_C,    KC_V,    KC_B,         KC_N,    KC_M,    KC_COMM, KC_DOT,  RSFT_T(KC_SLSH),
                               KC_LCTL, MO(SYM), KC_SPC,       KC_ENT,  MO(NAV), KC_BSPC
    ),
    [SYM] = LAYOUT_split_3x5_3(
        KC_1,    KC_2,    KC_3,    KC_4,    KC_5,              KC_6,    KC_7,    KC_8,    KC_9,    KC_0,
        KC_EXLM, KC_AT,   KC_HASH, KC_DLR,  KC_PERC,           KC_CIRC, KC_AMPR, KC_ASTR, KC_LPRN, KC_RPRN,
        KC_GRV,  KC_TILD, KC_BSLS, KC_PIPE, KC_MINS,           KC_EQL,  KC_PLUS, KC_LBRC, KC_RBRC, KC_QUOT,
                          _______, _______, _______,           _______, _______, KC_DEL
    ),
    [NAV] = LAYOUT_split_3x5_3(
        KC_ESC,  KC_TAB,  KC_CAPS, XXXXXXX, XXXXXXX,           KC_PGUP, KC_HOME, KC_UP,   KC_END,  KC_DEL,
        KC_LGUI, KC_LALT, KC_LCTL, KC_LSFT, XXXXXXX,           KC_PGDN, KC_LEFT, KC_DOWN, KC_RGHT, KC_BSPC,
        KC_F1,   KC_F2,   KC_F3,   KC_F4,   KC_F5,             KC_F6,   KC_F7,   KC_F8,   KC_F9,   KC_F10,
                          _______, _______, _______,           _______, _______, _______
    ),
    [ADJUST] = LAYOUT_split_3x5_3(
        QK_BOOT, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,           XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, QK_BOOT,
        KC_F11,  KC_F12,  XXXXXXX, XXXXXXX, XXXXXXX,           KC_MPRV, KC_VOLD, KC_VOLU, KC_MNXT, KC_MPLY,
        XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX, XXXXXXX,           XXXXXXX, KC_MUTE, XXXXXXX, XXXXXXX, XXXXXXX,
                          _______, _______, _______,           _______, _______, _______
    )
};

layer_state_t layer_state_set_user(layer_state_t state) {
    return update_tri_layer_state(state, SYM, NAV, ADJUST);
}
