#include <stdint.h>

#define UMIN_UMAX(width, type) \
  __attribute__((weak)) \
  type __sync_fetch_and_umin_##width(type *ptr, type value_to_write) { \
    type current_value = *(volatile type *)ptr; \
    while (1) { \
      type desired_value = (current_value < value_to_write) ? current_value : value_to_write; \
      type actual_mem_value = __sync_val_compare_and_swap(ptr, current_value, desired_value); \
      \
      if (actual_mem_value == current_value) return current_value; \
      current_value = actual_mem_value; \
    } \
  } \
  __attribute__((weak)) \
  type __sync_fetch_and_umax_##width(type *ptr, type value_to_write) { \
    type current_value = *(volatile type *)ptr; \
    while (1) { \
      type desired_value = (current_value > value_to_write) ? current_value : value_to_write; \
      type actual_mem_value = __sync_val_compare_and_swap(ptr, current_value, desired_value); \
      \
      if (actual_mem_value == current_value) return current_value; \
      current_value = actual_mem_value; \
    } \
  }

UMIN_UMAX(1, uint8_t)
UMIN_UMAX(2, uint16_t)
UMIN_UMAX(4, uint32_t)
