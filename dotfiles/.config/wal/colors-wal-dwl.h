/* Taken from https://github.com/djpohly/dwl/issues/466 */
#define COLOR(hex)    { ((hex >> 24) & 0xFF) / 255.0f, \
                        ((hex >> 16) & 0xFF) / 255.0f, \
                        ((hex >> 8) & 0xFF) / 255.0f, \
                        (hex & 0xFF) / 255.0f }

static const float rootcolor[]             = COLOR(0x282828ff);
static uint32_t colors[][3]                = {
	/*               fg          bg          border    */
	[SchemeNorm] = { 0xfbf1c7ff, 0x282828ff, 0x665c54ff },
	[SchemeSel]  = { 0xfbf1c7ff, 0xb8bb26ff, 0xfb4934ff },
	[SchemeUrg]  = { 0xfbf1c7ff, 0xfb4934ff, 0xb8bb26ff },
};
