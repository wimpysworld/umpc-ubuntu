/*
 * Copyright (c) 2022 Martin Wimpress <code@wimpress.io>
 *
 * orientation_changed() adapted from the sensorfw package
 * Copyright (C) 2009-2010 Nokia Corporation
 * Authors:
 *   Üstün Ergenoglu <ext-ustun.ergenoglu@nokia.com>
 *   Timo Rongas <ext-timo.2.rongas@nokia.com>
 *   Lihan Guo <lihan.guo@digia.com>
 *
 * gcc -O2 umpc-display-rotate.c -o umpc-display-rotate -lm
 *
 */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <dirent.h>
#include <errno.h>
#include <math.h>
#include <unistd.h>

#define NORMAL 0
#define INVERTED 1
#define RIGHT 2
#define LEFT 3

static const char *orientations[] = {
  "normal",
  "inverted",
  "right",
  "left",
  NULL
};

static const char *transforms[]  = {
  "0 -1 1 1 0 0 0 0 1",
  "0 1 0 -1 0 1 0 0 1",
  "1 0 0 0 1 0 0 0 1",
  "-1 0 1 0 -1 1 0 0 1",
  NULL
};

static const char touchy[][48] = {
  "GXTP7380:00 27C6:0113",                    //GPD Pocket 3
  "GXTP7380:00 27C6:0113 Stylus Pen (0)",     //GPD Pocket 3
  "GXTP7380:00 27C6:0113 Stylus Eraser (0)",  //GPD Pocket 3
  "Goodix Capacitive TouchScreen"             //TopJoy Falcon
};

static const char screens[][8] = {
  "DSI1"  //GPD Pocket 3 & TopJoy Falcon
};

#define RADIANS_TO_DEGREES 180.0/M_PI
#define SAME_AXIS_LIMIT 5
#define THRESHOLD_LANDSCAPE 35
#define THRESHOLD_PORTRAIT 35

/* First apply scale to get m/s², then
 * convert to 1G ~= 256 as the code expects */
#define SCALE(a) ((int) ((double) in_##a * scale * 256.0 / 9.81))

int orientation_changed(const double in_x, const double in_y, const double in_z,
                        const double scale, int *current_orientation) {
  int x, y, z;
  int portrait_rotation;
  int landscape_rotation;
  int new_orientation = RIGHT;

  /* this code expects 1G ~= 256 */
  x = SCALE(x);
  y = SCALE(y);
  z = SCALE(z);

  portrait_rotation  = round(atan2(x, sqrt(y * y + z * z)) * RADIANS_TO_DEGREES);
  landscape_rotation = round(atan2(y, sqrt(x * x + z * z)) * RADIANS_TO_DEGREES);

  /* Don't change orientation if we are on the common border of two thresholds */
  if (abs(portrait_rotation) > THRESHOLD_PORTRAIT && abs(landscape_rotation) > THRESHOLD_LANDSCAPE) {
    return 0;
  }

  /* Portrait check */
  if (abs(portrait_rotation) > THRESHOLD_PORTRAIT) {
    new_orientation = (portrait_rotation > 0) ? RIGHT : LEFT;

    /* Some threshold to switching between portrait modes */
    if (*current_orientation == RIGHT || *current_orientation == LEFT) {
      if (abs(portrait_rotation) < SAME_AXIS_LIMIT) {
        new_orientation = *current_orientation;
      }
    }
  } else {
    /* Landscape check */
    if (abs(landscape_rotation) > THRESHOLD_LANDSCAPE) {
      new_orientation = (landscape_rotation > 0) ? INVERTED : NORMAL;

      /* Some threshold to switching between landscape modes */
      if (*current_orientation == INVERTED || *current_orientation == NORMAL) {
        if (abs(landscape_rotation) < SAME_AXIS_LIMIT) {
          new_orientation = *current_orientation;
        }
      }
    }
  }

  if (*current_orientation != new_orientation) {
    *current_orientation = new_orientation;
    return 1;
  }
  return 0;
}

char* concat(const char *s1, const char *s2) {
  char *new = malloc(strlen(s1) + strlen(s2) + 1); // +1 for the null-terminator
  strcpy(stpcpy(new, s1), s2);
  return new;
}

// TODO: Only set properties of active devices
void rotate_touch(int orientation) {
  char cmd[384];

  // No checking if the device are present as xinput does "the right thing".
  for (size_t i = 0; i < sizeof(touchy) / sizeof(touchy[0]); i++) {
    fprintf(stdout, "  Rotating Touch: %s (%s)\n", touchy[i], orientations[orientation]);
    sprintf(cmd, "xinput set-prop \"%s\" \"Coordinate Transformation Matrix\" %s 2>/dev/null", touchy[i], transforms[orientation]);
    //fprintf(stderr, "  %s\n", cmd);
    int status = system(cmd);
  }
}

// TODO: Only rotate connected displays
void rotate(int orientation) {
  char cmd[64];
  int status = 0;

  rotate_touch(orientation);

  // Iterate over the supported internal displays; do not rotate external displays
  for (size_t i = 0; i < sizeof(screens) / sizeof(screens[0]); i++) {
    // Blank the screen while the rotation happens
    sprintf(cmd, "xrandr --output %s --brightness 0", screens[i]);
    status = system(cmd);

    fprintf(stdout, "  Rotating Screen: %s (%s)\n", screens[i], orientations[orientation]);
    sprintf(cmd, "xrandr --output %s --rotate %s", screens[i], orientations[orientation]);
    status = system(cmd);

    sleep(1);

    sprintf(cmd, "xrandr --output %s --brightness 1", screens[i]);
    status = system(cmd);
  }
}

double read_iio(char const *iio_dev, char const *sensor) {
  char content[32];
  char *fname = concat(iio_dev, sensor);
  double value = 0.0;

  FILE *fp = fopen(fname, "r");
  if (fp == NULL) {
    perror("Error opening file");
  }

  if (fgets(content, 32, fp) != NULL) {
    value = atof(content);
  }

  fclose(fp);
  free(fname);
  return value;
}

//TODO: Enumerate the iio:device path; don't hardcode
char* get_accelerometer(void) {
  return "/sys/bus/iio/devices/iio:device0";
}

//TODO: Detect Wayland and abort.
int main(int argc, char const *argv[]) {
  //2 is "right", the default orientation.
  //By initialising with 2, we avoid a needless rotation when the program starts
  int current_orientation = RIGHT;
  double raw_x, raw_y, raw_z, scale = 0.0;

  char* iio_dev = get_accelerometer();

  // Check that the IIO sensor is accessible
  DIR* dir = opendir(iio_dev);
  if (dir) {
    closedir(dir);
    fprintf(stdout, "Accelerometer: %s\n", iio_dev);
  } else {
    // IIO sensor directory does not exist/accessible
    fprintf(stdout, "Accelerometer: None.\n");
    return 1;
  }

  //Initialise the touch devices
  rotate_touch(current_orientation);

  // Get scaling factor
  scale = read_iio(iio_dev, "/in_accel_scale");

  // Poll the accelerometer
  for (;;) {
    raw_x = read_iio(iio_dev, "/in_accel_x_raw");
    raw_y = read_iio(iio_dev, "/in_accel_y_raw");
    raw_z = read_iio(iio_dev, "/in_accel_z_raw");

    if (orientation_changed(raw_x, raw_y, raw_z, scale, &current_orientation)) {
      rotate(current_orientation);
    } else {
      sleep(1.25);
    }
  }
  return 0;
}
