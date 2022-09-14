const std = @import("std");

const Vector = struct { x: f32, y: f32, z: f32 };

const Sphere = struct {
    point: Vector,
    color: Vector,
    specular: f32,
    lambert: f32,
    ambient: f32,
    radius: f32,
};

const Closest = struct { distance: f32, object: Sphere };

const Camera = struct {
  point: Vector,
  vector: Vector,
  fieldOfView: f32
};

const Scene = struct {
  objects: []const Sphere,
  lights: []const Vector,
  camera: Camera
};

const Ray = struct { point: Vector, vector: Vector };

const height: usize = 480;

const width: usize = 640;

var data = std.mem.zeroes([height][width][4]u8);

// Thx https://github.com/daneelsan/minimal-zig-wasm-canvas
// for this trick.
// The returned pointer will be used as an offset integer to the wasm memory
export fn getCheckerboardBufferPointer() [*]u8 {
    return @ptrCast([*]u8, &data);
}

var planet1: f32 = 0;
var planet2: f32 = 0;

export fn tick() void {
    const cam = Camera{
      .point = Vector{
          .x = 0,
          .y = 1.8,
          .z = 10,
      },
      .fieldOfView = 45,
      .vector = Vector{
          .x = 0,
          .y = 3,
          .z = 0,
      }
    };

    var sphere1 = .{
      .point = .{ .x = 0, .y = 3.5, .z = -3 },
      .color = .{ .x = 155, .y = 200, .z = 155 },
      .specular = 0.2, .lambert = 0.7, .ambient = 0.1, .radius = 3
    };


    var sphere2point = Vector {
      .x = std.math.sin(planet1) * 3.5,
      .z = -3.0 + std.math.cos(planet1) * 3.5,
      .y = 2
    };

    var sphere2 = .{
      .point = sphere2point,
      .color = .{
        .x = 155,
        .y = 155,
        .z = 155
      },
      .specular = 0.1,
      .lambert = 0.9,
      .ambient = 0.0,
      .radius = 0.2
    };

    var sphere3point = Vector {
      .y = 3,
      .x = std.math.sin(planet2) * 4,
      .z = -3 + std.math.cos(planet2) * 4
    };

    var sphere3 = .{
      .point = sphere3point,
      .color = .{
        .x = 255,
        .y = 255,
        .z = 255
      },
      .specular = 0.2,
      .lambert = 0.7,
      .ambient = 0.1,
      .radius = 0.1,
    };

    planet1 += 0.1;
    planet2 += 0.2;


    const scene = Scene{
      .lights = &.{.{ .x = -30, .y = -10, .z = 20 }},
      .camera = cam,
      .objects = &[_]Sphere{
         sphere1,
         sphere2,
         sphere3
      }
    };

    render(scene);

    return;
}

// # Vector Operations
//
// These are general-purpose functions that deal with vectors - in this case,
// three-dimensional vectors represented as objects in the form
//
//     { x, y, z }
//
// Since we're not using traditional object oriented techniques, these
// functions take and return that sort of logic-less object, so you'll see
// `add(a, b)` rather than `a.add(b)`.

// # Constants
const UP = Vector{ .x = 0, .y = 1, .z = 0 };
const ZERO = Vector{ .x = 0, .y = 0, .z = 0 };
const WHITE = Vector{ .x = 255, .y = 255, .z = 255 };

// # Operations
//
// ## [Dot Product](https://en.wikipedia.org/wiki/Dot_product)
// is different than the rest of these since it takes two vectors but
// returns a single number value.
fn dotProduct(a: Vector, b: Vector) f32 {
    return (a.x * b.x) + (a.y * b.y) + (a.z * b.z);
}

// ## [Cross Product](https://en.wikipedia.org/wiki/Cross_product)
//
// generates a new vector that's perpendicular to both of the vectors
// given.
fn crossProduct(a: Vector, b: Vector) Vector {
    return Vector{ .x = (a.y * b.z) - (a.z * b.y), .y = (a.z * b.x) - (a.x * b.z), .z = (a.x * b.y) - (a.y * b.x) };
}

// Enlongate or shrink a vector by a factor of `t`
fn scale(a: Vector, t: f32) Vector {
    return Vector{ .x = a.x * t, .y = a.y * t, .z = a.z * t };
}

// ## [Unit Vector](http://en.wikipedia.org/wiki/Unit_vector)
//
// Turn any vector into a vector that has a magnitude of 1.
//
// If you consider that a [unit sphere](http://en.wikipedia.org/wiki/Unit_sphere)
// is a sphere with a radius of 1, a unit vector is like a vector from the
// center point (0, 0, 0) to any point on its surface.
fn unitVector(a: Vector) Vector {
    return scale(a, 1 / length(a));
}
//
// // Add two vectors to each other, by simply combining each
// // of their components
fn add(a: Vector, b: Vector) Vector {
    return Vector{ .x = a.x + b.x, .y = a.y + b.y, .z = a.z + b.z };
}
//
// // A version of `add` that adds three vectors at the same time. While
// // it's possible to write a clever version of `Vector.add` that takes
// // any number of arguments, it's not fast, so we're keeping it simple and
// // just making two versions.
fn add3(a: Vector, b: Vector, c: Vector) Vector {
    return Vector{ .x = a.x + b.x + c.x, .y = a.y + b.y + c.y, .z = a.z + b.z + c.z };
}
//
// // Subtract one vector from another, by subtracting each component
fn subtract(a: Vector, b: Vector) Vector {
    return Vector{
      .x = a.x - b.x,
      .y = a.y - b.y,
      .z = a.z - b.z
    };
}
//
// // Length, or magnitude, measured by [Euclidean norm](https://en.wikipedia.org/wiki/Euclidean_vector#Length)
fn length(a: Vector) f32 {
    return @sqrt(dotProduct(a, a));
}
//
// // Given a vector `a`, which is a point in space, and a `normal`, which is
// // the angle the point hits a surface, returna  new vector that is reflect
// // off of that surface
fn reflectThrough(a: Vector, normal: Vector) Vector {
    const d = scale(normal, dotProduct(a, normal));
    return subtract(scale(d, 2), a);
}

fn sphereIntersection(sphere: Sphere, ray: Ray) f32 {
    const eye_to_center = subtract(sphere.point, ray.point);
    // picture a triangle with one side going straight from the camera point
    // to the center of the sphere, another side being the vector.
    // the final side is a right angle.
    //
    // This equation first figures out the length of the vector side
    const v = dotProduct(eye_to_center, ray.vector);
    // then the length of the straight from the camera to the center
    // of the sphere
    const eoDot = dotProduct(eye_to_center, eye_to_center);
    // and compute a segment from the right angle of the triangle to a point
    // on the `v` line that also intersects the circle
    const discriminant = sphere.radius * sphere.radius - eoDot + v * v;

    // If the discriminant is negative, that means that the sphere hasn't
    // been hit by the ray
    if (discriminant < 0) {
        return 0.0;
    } else {
        // otherwise, we return the distance from the camera point to the sphere
        // `Math.sqrt(dotProduct(a, a))` is the length of a vector, so
        // `v - Math.sqrt(discriminant)` means the length of the the vector
        // just from the camera to the intersection point.
        return v - @sqrt(discriminant);
    }
}

fn sphereNormal(sphere: Sphere, pos: Vector) Vector {
    return unitVector(subtract(pos, sphere.point));
}

fn intersectScene(ray: Ray, scene: Scene) ?Closest {

    // The base case is that it hits nothing, and travels for `Infinity`
    var closest: ?Closest = null;
    var distance = std.math.inf(f32);

    // But for each object, we check whether it has any intersection,
    // and compare that intersection - is it closer than `Infinity` at first,
    // and then is it closer than other objects that have been hit?
    for (scene.objects) |object| {
        const dist = sphereIntersection(object, ray);
        if (dist != 0 and dist < distance) {
            distance = dist;
            closest = Closest{ .distance = dist, .object = object };
        }
    }

    return closest;
}

fn isLightVisible(pt: Vector, scene: Scene, light: Vector) bool {
    const distObject = intersectScene(Ray{
        .point = pt,
        .vector = unitVector(subtract(pt, light)),
    }, scene) orelse return false;
    return distObject.distance > -0.005;
}

// # Surface
//
// ![](http://farm3.staticflickr.com/2851/10524788334_f2e3903b36_b.jpg)
//
// If `trace()` determines that a ray intersected with an object, `surface`
// decides what color it acquires from the interaction.
fn surface(ray: Ray, scene: Scene, object: Sphere, pointAtTime: Vector, normal: Vector, depth: f32) Vector {
    var b = object.color;
    var c = ZERO;
    var lambertAmount: f32 = 0;
    var d = depth;

    // **[Lambert shading](http://en.wikipedia.org/wiki/Lambertian_reflectance)**
    // is our pretty shading, which shows gradations from the most lit point on
    // the object to the least.
    if (object.lambert > 0) {
        for (scene.lights) |lightPoint| {
            // First: can we see the light? If not, this is a shadowy area
            // and it gets no light from the lambert shading process.
            if (!isLightVisible(pointAtTime, scene, lightPoint)) {
              continue;
            }
            // Otherwise, calculate the lambertian reflectance, which
            // essentially is a 'diffuse' lighting system - direct light
            // is bright, and from there, less direct light is gradually,
            // beautifully, less light.
            var contribution = dotProduct(unitVector(subtract(lightPoint, pointAtTime)), normal);
            // sometimes this formula can return negatives, so we check:
            // we only want positive values for lighting.
            if (contribution > 0) {
              lambertAmount += contribution;
            }
        }
    }

    // **[Specular](https://en.wikipedia.org/wiki/Specular_reflection)** is a fancy word for 'reflective': rays that hit objects
    // with specular surfaces bounce off and acquire the colors of other objects
    // they bounce into.
    if (object.specular > 0) {
        // This is basically the same thing as what we did in `render()`, just
        // instead of looking from the viewpoint of the camera, we're looking
        // from a point on the surface of a shiny object, seeing what it sees
        // and making that part of a reflection.
        var reflectedRay = Ray {
            .point = pointAtTime,
            .vector = reflectThrough(ray.vector, normal),
        };
        d = d + 1;
        var reflectedColor = trace(reflectedRay, scene, d);
        if (reflectedColor) |reflected| {
            c = add(c, scale(reflected, object.specular));
        }
    }

    // lambert should never 'blow out' the lighting of an object,
    // even if the ray bounces between a lot of things and hits lights
    lambertAmount = @minimum(1, lambertAmount);

    // **Ambient** colors shine bright regardless of whether there's a light visible -
    // a circle with a totally ambient blue color will always just be a flat blue
    // circle.
    return add3(c, scale(b, lambertAmount * object.lambert), scale(b, object.ambient));
}

// # Trace
//
// Given a ray, shoot it until it hits an object and return that object's color,
// or `Vector.WHITE` if no object is found. This is the main function that's
// called in order to draw the image, and it recurses into itself if rays
// reflect off of objects and acquire more color.
fn trace(ray: Ray, scene: Scene, depth: f32) ?Vector {
    // This is a recursive method: if we hit something that's reflective,
    // then the call to `surface()` at the bottom will return here and try
    // to find what the ray reflected into. Since this could easily go
    // on forever, first check that we haven't gone more than three bounces
    // into a reflection.
    if (depth > 3) {
      return null;
    }

    var distObject = intersectScene(ray, scene) orelse return WHITE;

    var q = distObject;
    var dist = q.distance;
    var object = q.object;

    // The `pointAtTime` is another way of saying the 'intersection point'
    // of this ray into this object. We compute this by simply taking
    // the direction of the ray and making it as long as the distance
    // returned by the intersection check.
    var pointAtTime = add(ray.point, scale(ray.vector, dist));

    return surface(ray, scene, object, pointAtTime,
      sphereNormal(object, pointAtTime),
      depth);
}

fn render(scene: Scene) void {
    // first 'unpack' the scene to make it easier to reference
    var camera = scene.camera;

    // This process
    // is a bit odd, because there's a disconnect between pixels and vectors:
    // given the left and right, top and bottom rays, the rays we shoot are just
    // interpolated between them in little increments.
    //
    // Starting with the height and width of the scene, the camera's place,
    // direction, and field of view, we calculate factors that create
    // `width*height` vectors for each ray

    // Start by creating a simple vector pointing in the direction the camera is
    // pointing - a unit vector
    var eyeVector = unitVector(subtract(camera.vector, camera.point));
    // and then we'll rotate this by combining it with a version that's turned
    // 90° right and one that's turned 90° up. Since the [cross product](http://en.wikipedia.org/wiki/Cross_product)
    // takes two vectors and creates a third that's perpendicular to both,
    // we use a pure 'UP' vector to turn the camera right, and that 'right'
    // vector to turn the camera up.
    var vpRight = unitVector(crossProduct(eyeVector, UP));
    var vpUp = unitVector(crossProduct(vpRight, eyeVector));
    // The actual ending pixel dimensions of the image aren't important here -
    // note that `width` and `height` are in pixels, but the numbers we compute
    // here are just based on the ratio between them, `height/width`, and the
    // `fieldOfView` of the camera.
    var fovRadians = (std.math.pi * (camera.fieldOfView / 2)) / 180;
    const heightWidthRatio = @intToFloat(f32, height) / @intToFloat(f32, width);
    var halfWidth = std.math.tan(fovRadians);
    var halfHeight = heightWidthRatio * halfWidth;
    var camerawidth = halfWidth * 2;
    var cameraheight = halfHeight * 2;
    var pixelWidth = camerawidth / (@intToFloat(f32, width) - 1);
    var pixelHeight = cameraheight / (@intToFloat(f32, height) - 1);

    var index: usize = 0;
    var ray = Ray{ .point = camera.point, .vector = ZERO };
    var x: usize = 0;
    while (x < width) {
        var y: usize = 0;
        while (y < height) {
            // turn the raw pixel `x` and `y` values into values from -1 to 1
            // and use these values to scale the facing-right and facing-up
            // vectors so that we generate versions of the `eyeVector` that are
            // skewed in each necessary direction.
            var xcomp = scale(vpRight, @intToFloat(f32, x) * pixelWidth - halfWidth);
            var ycomp = scale(vpUp, @intToFloat(f32, y) * pixelHeight - halfHeight);

            ray.vector = unitVector(add3(eyeVector, xcomp, ycomp));

            // use the vector generated to raytrace the scene, returning a color
            // as a `{x, y, z}` vector of RGB values
            const color = trace(ray, scene, 0) orelse WHITE;

            index = x * 4 + y * width * 4;
            data[y][x][0] = @floatToInt(u8, color.x);
            data[y][x][1] = @floatToInt(u8, color.y);
            data[y][x][2] = @floatToInt(u8, color.z);
            data[y][x][3] = 255;
            y += 1;
        }
        x += 1;
    }

    // Now that each ray has returned and populated the `data` array with
    // correctly lit colors, fill the canvas with the generated data.
    return;
}
