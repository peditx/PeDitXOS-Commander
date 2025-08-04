#!/bin/sh

# Display the main menu with fixed names
echo "Main Menu:"
echo "1) apple"
echo "2) banana"
echo "3) cherry"
echo "4) date"
echo "5) elderberry"
echo "6) fig"
echo "7) grape"
echo "8) honeydew"
echo "9) kiwi"
echo "10) lemon"

# Get user selection
printf "Please select an option (1-10): "
read main_choice

# Map number to item name
case "$main_choice" in
  1) main_name="apple" ;;
  2) main_name="banana" ;;
  3) main_name="cherry" ;;
  4) main_name="date" ;;
  5) main_name="elderberry" ;;
  6) main_name="fig" ;;
  7) main_name="grape" ;;
  8) main_name="honeydew" ;;
  9) main_name="kiwi" ;;
  10) main_name="lemon" ;;
  *) echo "Invalid option."; exit 1 ;;
esac

# Show submenu
echo ""
echo "Submenu for '$main_name':"
i=1
while [ $i -le 10 ]; do
  echo "$i) ${main_name}_sub_$i"
  i=$((i + 1))
done

# Get submenu selection
printf "Please select a sub-option (1-10): "
read sub_choice

# Final action
case "$sub_choice" in
  [1-9]|10) echo ""; echo "hello ped ✅" ;;
  *) echo "Invalid sub-option."; exit 1 ;;
esac
