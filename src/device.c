#define R_NO_REMAP
#include <R.h>
#include <Rinternals.h>
#include <R_ext/GraphicsEngine.h>
#include <R_ext/GraphicsDevice.h>
#include <R_ext/Rdynload.h>
#include <R_ext/Visibility.h>
#include <stdlib.h>
#include <stdio.h>
#include <string.h>

/* Graphics engine interface. Recording and serialization are handled in R. */
typedef struct {
    SEXP emit;
    SEXP metrics;
} CetzDevice;

static SEXP colour(int value) {
    char buffer[10];
    snprintf(buffer, sizeof(buffer), "#%02x%02x%02x%02x",
             R_RED(value), R_GREEN(value), R_BLUE(value), R_ALPHA(value));
    return Rf_mkString(buffer);
}

static SEXP context(const pGEcontext gc) {
    const char *names[] = {"col", "fill", "lwd", "lty", "lend", "ljoin",
                           "lmitre", "size", "face", "family", "pattern"};
    SEXP out = PROTECT(Rf_allocVector(VECSXP, 11));
    SEXP nm = PROTECT(Rf_allocVector(STRSXP, 11));
    for (int i = 0; i < 11; ++i) SET_STRING_ELT(nm, i, Rf_mkChar(names[i]));
    SET_VECTOR_ELT(out, 0, colour(gc->col));
    SET_VECTOR_ELT(out, 1, colour(gc->fill));
    SET_VECTOR_ELT(out, 2, Rf_ScalarReal(gc->lwd));
    SET_VECTOR_ELT(out, 3, Rf_ScalarInteger(gc->lty));
    SET_VECTOR_ELT(out, 4, Rf_ScalarInteger(gc->lend));
    SET_VECTOR_ELT(out, 5, Rf_ScalarInteger(gc->ljoin));
    SET_VECTOR_ELT(out, 6, Rf_ScalarReal(gc->lmitre));
    SET_VECTOR_ELT(out, 7, Rf_ScalarReal(gc->ps * gc->cex));
    SET_VECTOR_ELT(out, 8, Rf_ScalarInteger(gc->fontface));
    SET_VECTOR_ELT(out, 9, Rf_ScalarString(Rf_mkCharCE(gc->fontfamily, CE_UTF8)));
    SET_VECTOR_ELT(out, 10, Rf_ScalarInteger(Rf_isNull(gc->patternFill) ?
                                          NA_INTEGER : Rf_asInteger(gc->patternFill)));
    Rf_setAttrib(out, R_NamesSymbol, nm);
    UNPROTECT(2);
    return out;
}

static SEXP numbers(const double *values, int n) {
    SEXP out = PROTECT(Rf_allocVector(REALSXP, n));
    if (n) memcpy(REAL(out), values, n * sizeof(double));
    UNPROTECT(1);
    return out;
}

#if R_GE_version >= 17
static SEXP eval_callback_body(void *data) {
    return Rf_eval((SEXP) data, R_GlobalEnv);
}

static void unlock_callback_error(void *data, Rboolean jump) {
    pGEDevDesc ge = data;
    /* R 4.6's begincontext() clears the engine's unlock handler.
       Release the lock on unwind; leave normal returns to the engine. */
    if (jump && GEdeviceNumber(ge)) ge->lock = FALSE;
}
#endif

static SEXP eval_callback(SEXP call, pDevDesc dd) {
#if R_GE_version >= 17
    return R_UnwindProtect(eval_callback_body, call, unlock_callback_error,
                           desc2GEDesc(dd), NULL);
#else
    return Rf_eval(call, R_GlobalEnv);
#endif
}

static SEXP emit(const char *kind, SEXP data, const pGEcontext gc, pDevDesc dd) {
    CetzDevice *device = dd->deviceSpecific;
    PROTECT(data);
    SEXP style = PROTECT(gc ? context(gc) : R_NilValue);
    SEXP type = PROTECT(Rf_mkString(kind));
    SEXP call = PROTECT(Rf_lang4(device->emit, type, data, style));
    SEXP result = eval_callback(call, dd);
    UNPROTECT(4);
    return result;
}

static void cetz_close(pDevDesc dd) {
    CetzDevice *device = dd->deviceSpecific;
    if (!device) return;
    SEXP type = PROTECT(Rf_mkString("close"));
    SEXP call = PROTECT(Rf_lang4(device->emit, type, R_NilValue, R_NilValue));
    int error = 0;
    SEXP result = PROTECT(R_tryEval(call, R_GlobalEnv, &error));
    R_ReleaseObject(device->emit);
    R_ReleaseObject(device->metrics);
    free(device);
    dd->deviceSpecific = NULL;
    if (error) Rf_warning("cetzDevice could not finish writing its output file");
    else if (TYPEOF(result) == STRSXP && Rf_length(result) > 0)
        Rf_warning("Could not write CeTZ output: %s", CHAR(STRING_ELT(result, 0)));
    UNPROTECT(3);
}

static void cetz_page(const pGEcontext gc, pDevDesc dd) {
    emit("page", R_NilValue, gc, dd);
}

static void cetz_size(double *left, double *right, double *bottom,
                      double *top, pDevDesc dd) {
    *left = dd->left; *right = dd->right;
    *bottom = dd->bottom; *top = dd->top;
}

static void cetz_clip(double x0, double x1, double y0, double y1, pDevDesc dd) {
    double values[] = {x0, x1, y0, y1};
    emit("clip", numbers(values, 4), NULL, dd);
}

static void cetz_line(double x0, double y0, double x1, double y1,
                      const pGEcontext gc, pDevDesc dd) {
    double values[] = {x0, y0, x1, y1};
    emit("line", numbers(values, 4), gc, dd);
}

static void cetz_rect(double x0, double y0, double x1, double y1,
                      const pGEcontext gc, pDevDesc dd) {
    double values[] = {x0, y0, x1, y1};
    emit("rect", numbers(values, 4), gc, dd);
}

static void cetz_circle(double x, double y, double r,
                        const pGEcontext gc, pDevDesc dd) {
    double values[] = {x, y, r};
    emit("circle", numbers(values, 3), gc, dd);
}

static void poly(const char *kind, int n, double *x, double *y,
                 const pGEcontext gc, pDevDesc dd) {
    if (n < 2) return;
    SEXP data = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(data, 0, numbers(x, n));
    SET_VECTOR_ELT(data, 1, numbers(y, n));
    emit(kind, data, gc, dd);
    UNPROTECT(1);
}

static void cetz_polygon(int n, double *x, double *y,
                         const pGEcontext gc, pDevDesc dd) {
    poly("polygon", n, x, y, gc, dd);
}

static void cetz_polyline(int n, double *x, double *y,
                          const pGEcontext gc, pDevDesc dd) {
    poly("polyline", n, x, y, gc, dd);
}

static void cetz_path(double *x, double *y, int npoly, int *nper,
                      Rboolean winding, const pGEcontext gc, pDevDesc dd) {
    int n = 0;
    for (int i = 0; i < npoly; ++i) n += nper[i];
    SEXP data = PROTECT(Rf_allocVector(VECSXP, 4));
    SET_VECTOR_ELT(data, 0, numbers(x, n));
    SET_VECTOR_ELT(data, 1, numbers(y, n));
    SEXP counts = PROTECT(Rf_allocVector(INTSXP, npoly));
    memcpy(INTEGER(counts), nper, npoly * sizeof(int));
    SET_VECTOR_ELT(data, 2, counts);
    SET_VECTOR_ELT(data, 3, Rf_ScalarLogical(winding));
    emit("path", data, gc, dd);
    UNPROTECT(2);
}

static void cetz_text(double x, double y, const char *str, double rot,
                      double hadj, const pGEcontext gc, pDevDesc dd) {
    double values[] = {x, y, rot, hadj};
    SEXP data = PROTECT(Rf_allocVector(VECSXP, 2));
    SET_VECTOR_ELT(data, 0, numbers(values, 4));
    SET_VECTOR_ELT(data, 1, Rf_ScalarString(Rf_mkCharCE(str, CE_UTF8)));
    emit("text", data, gc, dd);
    UNPROTECT(1);
}

static void cetz_raster(unsigned int *raster, int w, int h, double x, double y,
                        double width, double height, double rot,
                        Rboolean interpolate, const pGEcontext gc, pDevDesc dd) {
    if (w <= 0 || h <= 0 || width == 0 || height == 0) return;
    SEXP data = PROTECT(Rf_allocVector(VECSXP, 2));
    SEXP pixels = PROTECT(Rf_allocMatrix(INTSXP, h, w));
    /* nativeRaster uses row-major ABGR storage despite its R matrix dimensions. */
    memcpy(INTEGER(pixels), raster, (size_t) w * h * sizeof(unsigned int));
    SEXP class = PROTECT(Rf_mkString("nativeRaster"));
    Rf_setAttrib(pixels, R_ClassSymbol, class);
    SET_VECTOR_ELT(data, 0, pixels);
    double geometry[] = {x, y, width, height, rot, interpolate ? 1 : 0};
    SET_VECTOR_ELT(data, 1, numbers(geometry, 6));
    emit("raster", data, NULL, dd);
    UNPROTECT(3);
}

static SEXP measure(SEXP text, const pGEcontext gc, pDevDesc dd) {
    CetzDevice *device = dd->deviceSpecific;
    PROTECT(text);
    SEXP style = PROTECT(context(gc));
    SEXP call = PROTECT(Rf_lang3(device->metrics, text, style));
    SEXP result = eval_callback(call, dd);
    UNPROTECT(3);
    return result;
}

static double cetz_width(const char *str, const pGEcontext gc, pDevDesc dd) {
    SEXP text = PROTECT(Rf_ScalarString(Rf_mkCharCE(str, CE_UTF8)));
    SEXP result = PROTECT(measure(text, gc, dd));
    double width = REAL(result)[0];
    UNPROTECT(2);
    return width;
}

static void cetz_metric(int c, const pGEcontext gc, double *ascent,
                        double *descent, double *width, pDevDesc dd) {
    SEXP code = PROTECT(Rf_ScalarInteger(c < 0 ? -c : c));
    SEXP result = PROTECT(measure(code, gc, dd));
    *width = REAL(result)[0];
    *ascent = REAL(result)[1];
    *descent = REAL(result)[2];
    UNPROTECT(2);
}

static SEXP cetz_pattern(SEXP pattern, pDevDesc dd) {
    if (Rf_isNull(pattern)) return R_NilValue;
    int type = R_GE_patternType(pattern);
    if (type != R_GE_linearGradientPattern && type != R_GE_radialGradientPattern) {
        Rf_warning("cetzDevice does not yet support tiling patterns");
        return R_NilValue;
    }
    SEXP data = PROTECT(Rf_allocVector(VECSXP, 5));
    SET_VECTOR_ELT(data, 0, Rf_ScalarInteger(type));
    int n, extend;
    if (type == R_GE_linearGradientPattern) {
        double at[] = {R_GE_linearGradientX1(pattern), R_GE_linearGradientY1(pattern),
                       R_GE_linearGradientX2(pattern), R_GE_linearGradientY2(pattern)};
        SET_VECTOR_ELT(data, 1, numbers(at, 4));
        n = R_GE_linearGradientNumStops(pattern);
        extend = R_GE_linearGradientExtend(pattern);
    } else {
        double at[] = {R_GE_radialGradientCX1(pattern), R_GE_radialGradientCY1(pattern),
                       R_GE_radialGradientR1(pattern), R_GE_radialGradientCX2(pattern),
                       R_GE_radialGradientCY2(pattern), R_GE_radialGradientR2(pattern)};
        SET_VECTOR_ELT(data, 1, numbers(at, 6));
        n = R_GE_radialGradientNumStops(pattern);
        extend = R_GE_radialGradientExtend(pattern);
    }
    SEXP stops = PROTECT(Rf_allocVector(REALSXP, n));
    SEXP colours = PROTECT(Rf_allocVector(STRSXP, n));
    for (int i = 0; i < n; ++i) {
        REAL(stops)[i] = type == R_GE_linearGradientPattern ?
            R_GE_linearGradientStop(pattern, i) : R_GE_radialGradientStop(pattern, i);
        int col = type == R_GE_linearGradientPattern ?
            R_GE_linearGradientColour(pattern, i) : R_GE_radialGradientColour(pattern, i);
        SEXP value = PROTECT(colour(col));
        SET_STRING_ELT(colours, i, STRING_ELT(value, 0));
        UNPROTECT(1);
    }
    SET_VECTOR_ELT(data, 2, stops);
    SET_VECTOR_ELT(data, 3, colours);
    SET_VECTOR_ELT(data, 4, Rf_ScalarInteger(extend));
    SEXP result = emit("pattern", data, NULL, dd);
    UNPROTECT(3);
    return result;
}

/* Graphics engine capabilities and unsupported operations. */
#if R_GE_version >= 15
static SEXP cetz_capabilities(SEXP cap) {
    PROTECT(cap);
    SEXP patterns = PROTECT(Rf_allocVector(INTSXP, 2));
    INTEGER(patterns)[0] = R_GE_linearGradientPattern;
    INTEGER(patterns)[1] = R_GE_radialGradientPattern;
    SET_VECTOR_ELT(cap, R_GE_capability_patterns, patterns);
    for (int i = R_GE_capability_clippingPaths; i <= R_GE_capability_paths; ++i)
        SET_VECTOR_ELT(cap, i, Rf_ScalarInteger(0));
#if R_GE_version >= 16
    SET_VECTOR_ELT(cap, R_GE_capability_glyphs, Rf_ScalarInteger(0));
#endif
    UNPROTECT(2);
    return cap;
}
static SEXP unsupported_group(SEXP source, int op, SEXP destination, pDevDesc dd) {
    Rf_warning("cetzDevice does not yet support compositing groups");
    return R_NilValue;
}
static void unsupported_use_group(SEXP ref, SEXP trans, pDevDesc dd) { }
static void unsupported_stroke(SEXP path, const pGEcontext gc, pDevDesc dd) {
    Rf_warning("cetzDevice does not yet support stroke path callbacks");
}
static void unsupported_fill(SEXP path, int rule, const pGEcontext gc, pDevDesc dd) {
    Rf_warning("cetzDevice does not yet support fill path callbacks");
}
#endif
static SEXP unsupported_clip(SEXP path, SEXP ref, pDevDesc dd) {
    if (!Rf_isNull(path)) Rf_warning("cetzDevice does not yet support non-rectangular clip paths");
    return R_NilValue;
}
static SEXP unsupported_mask(SEXP mask, SEXP ref, pDevDesc dd) {
    if (!Rf_isNull(mask)) Rf_warning("cetzDevice does not yet support masks");
    return R_NilValue;
}
static void release_resource(SEXP ref, pDevDesc dd) { }

SEXP cetz_device(SEXP callbacks, SEXP width, SEXP height, SEXP pointsize, SEXP bg, SEXP fg) {
    R_GE_checkVersionOrDie(R_GE_version);
    R_CheckDeviceAvailable();
    pDevDesc dd = calloc(1, sizeof(DevDesc));
    CetzDevice *device = calloc(1, sizeof(CetzDevice));
    if (!dd || !device) {
        free(dd); free(device);
        Rf_error("Unable to allocate cetzDevice");
    }
    device->emit = VECTOR_ELT(callbacks, 0);
    device->metrics = VECTOR_ELT(callbacks, 1);
    R_PreserveObject(device->emit);
    R_PreserveObject(device->metrics);
    dd->deviceSpecific = device;
    dd->left = dd->bottom = 0;
    dd->right = Rf_asReal(width) * 72;
    dd->top = Rf_asReal(height) * 72;
    dd->clipLeft = dd->left; dd->clipRight = dd->right;
    dd->clipBottom = dd->bottom; dd->clipTop = dd->top;
    dd->ipr[0] = dd->ipr[1] = 1.0 / 72;
    double ps = Rf_asReal(pointsize);
    dd->cra[0] = 0.9 * ps; dd->cra[1] = 1.2 * ps;
    dd->xCharOffset = 0.4900; dd->yCharOffset = 0.3333; dd->yLineBias = 0.2;
    dd->gamma = dd->startgamma = 1;
    dd->canClip = TRUE;
    dd->canHAdj = 2;
    dd->startps = ps;
    dd->startcol = (int) (unsigned int) Rf_asReal(fg);
    dd->startfill = (int) (unsigned int) Rf_asReal(bg);
    dd->startlty = LTY_SOLID; dd->startfont = 1;
    dd->displayListOn = FALSE;
    dd->close = cetz_close; dd->newPage = cetz_page; dd->size = cetz_size;
    dd->clip = cetz_clip; dd->line = cetz_line; dd->rect = cetz_rect;
    dd->circle = cetz_circle; dd->polygon = cetz_polygon;
    dd->polyline = cetz_polyline; dd->path = cetz_path;
    dd->raster = cetz_raster;
    dd->text = dd->textUTF8 = cetz_text;
    dd->strWidth = dd->strWidthUTF8 = cetz_width;
    dd->metricInfo = cetz_metric;
    dd->hasTextUTF8 = dd->wantSymbolUTF8 = TRUE;
    dd->useRotatedTextInContour = TRUE;
    dd->haveTransparency = 2; dd->haveTransparentBg = 3;
    dd->haveRaster = 2;
    dd->haveCapture = dd->haveLocator = 1;
    dd->setPattern = cetz_pattern;
    dd->releasePattern = dd->releaseClipPath = dd->releaseMask = release_resource;
    dd->setClipPath = unsupported_clip; dd->setMask = unsupported_mask;
    dd->deviceVersion = R_GE_definitions;
#if R_GE_version >= 15
    dd->deviceVersion = R_GE_group;
    dd->capabilities = cetz_capabilities;
    dd->defineGroup = unsupported_group; dd->useGroup = unsupported_use_group;
    dd->releaseGroup = release_resource;
    dd->stroke = unsupported_stroke;
    dd->fill = dd->fillStroke = unsupported_fill;
#endif
    BEGIN_SUSPEND_INTERRUPTS {
        pGEDevDesc ge = GEcreateDevDesc(dd);
        GEaddDevice2(ge, "cetzDevice");
        GEinitDisplayList(ge);
    } END_SUSPEND_INTERRUPTS;
    return R_NilValue;
}

static const R_CallMethodDef call_methods[] = {
    {"cetz_device", (DL_FUNC) &cetz_device, 6},
    {NULL, NULL, 0}
};

void attribute_visible R_init_cetzDevice(DllInfo *dll) {
    R_registerRoutines(dll, NULL, call_methods, NULL, NULL);
    R_useDynamicSymbols(dll, FALSE);
    R_forceSymbols(dll, TRUE);
}
