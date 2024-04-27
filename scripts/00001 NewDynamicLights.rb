# Hello maker!
# If you're reading this, it means you've probably read the HOW TO CREATE A CUSTOM SCRIPT.md file. If not, please have
# a look at it, I (Rey) took a lot of time to write it!
#
#
# I will assume from now on you HAVE read the mentioned file (and have learned Ruby to ).
# Below, you will find an example of something you can do to modify/add new code to PSDK.
# In this example, we're adding a new light to the DynamicLight feature.
#
# As you can see, to monkey-patch or to add anything to the code, you need to tell Ruby what you'll modify.
# This is done by writing the proper modules/classes. In this code, we're opening the module NuriYuri, then the
# module DynamicLight.
# Finally, as LIGHTS is a constant, and an Array, this means we can add values in it without having to modify the
# constant itself!

module NuriYuri
  module DynamicLight
    LIGHTS.push([:normal, 'dynamic_light/wall_light_48'])
    LIGHTS.push([:normal, 'dynamic_light/circle_32_purple'])
  end
end
