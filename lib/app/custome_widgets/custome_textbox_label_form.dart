import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/app_theme.dart';
import 'custome_star_lable.dart';

class CustomeTextBoxLabelForm extends StatelessWidget {
  final String? labelText;
  final String? hintText;
  final String? initialValue;
  final Widget? suffixIcon;
  final EdgeInsetsGeometry? contentPadding;
  final int maxLines;
  final int? maxLength;
  final TextEditingController? controller;
  final bool enabled;
  final bool isBorderRequired;
  final bool realOnly;
  final TextAlign? textAlign;
  final String? Function(String?)? validator;
  final String? Function(String?)? onChanged;
  final VoidCallback? onTap;
  final TextInputType keyboardType;
  final FocusNode? focusNode;
  final bool? obscureText;
  final bool? enableOnlyDigits;
  final bool isRequired;
  final VoidCallback? onEditingComplete;
  final List<TextInputFormatter>? inputFormatters;

  const CustomeTextBoxLabelForm({
    super.key,
    this.labelText,
    this.hintText,
    this.initialValue,
    this.suffixIcon,
    this.contentPadding,
    this.maxLines = 1,
    this.maxLength,
    this.controller,
    this.textAlign,
    this.enabled = true,
    this.isBorderRequired = true,
    this.realOnly = false,
    // required String? Function(dynamic value) validator,
    this.validator,
    this.onChanged,
    this.onTap,
    this.onEditingComplete,
    this.keyboardType = TextInputType.text,
    this.focusNode,
    this.obscureText = false,
    this.enableOnlyDigits = false,
    this.isRequired = false,
    this.inputFormatters,
  });

  @override
  Widget build(BuildContext context) {
    final customTheme = CustomTheme.of(context);
    final textTheme = Theme.of(context).textTheme;
    final radius = BorderRadius.circular(AppRadii.md);
    final border = customTheme.borderLightGray;
    final inputBorder = isBorderRequired
        ? OutlineInputBorder(
            borderSide: BorderSide(color: border),
            borderRadius: radius,
          )
        : OutlineInputBorder(
            borderSide: BorderSide(color: border.withValues(alpha: 0)),
            borderRadius: radius,
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (labelText?.isNotEmpty ?? false) ...[
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Flexible(
                child: Text(
                  labelText!,
                  style: textTheme.labelLarge?.copyWith(
                    color: customTheme.textDefault,
                  ),
                ),
              ),
              if (isRequired) const CustomeStarLable(),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
        ],
        TextFormField(
          initialValue: initialValue,
          inputFormatters: inputFormatters,
          // inputFormatters: (enableOnlyDigits ?? false)
          //     ? <TextInputFormatter>[
          //         FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
          //         FilteringTextInputFormatter.digitsOnly,
          //         // LengthLimitingTextInputFormatter(10),
          //       ]
          //     : null,
          textAlign: textAlign ?? TextAlign.start,
          validator: enabled ? validator : null,
          controller: controller,
          readOnly: realOnly,
          enabled: enabled,
          maxLines: obscureText == true ? 1 : maxLines,
          // maxLength: maxLength,
          maxLength: maxLength,
          keyboardType: keyboardType,
          focusNode: focusNode,
          onChanged: enabled ? onChanged : null,
          onEditingComplete: enabled ? onEditingComplete : null,
          onTap: enabled
              ? () {
                  if (onTap != null) {
                    onTap!();
                  }
                }
              : null,
          obscureText: obscureText ?? false,

          style: textTheme.bodyMedium,

          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: textTheme.bodyMedium?.copyWith(
              color: customTheme.textLightGray,
            ),
            contentPadding: contentPadding ??
                const EdgeInsets.symmetric(
                  horizontal: AppSpacing.lg,
                  vertical: AppSpacing.md,
                ),
            fillColor:
                enabled ? customTheme.bgColor : AppColors.scaffoldBackground,
            filled: true,
            disabledBorder: inputBorder,
            enabledBorder: inputBorder,
            focusedBorder: isBorderRequired
                ? OutlineInputBorder(
                    borderSide: BorderSide(
                      color: customTheme.primaryColor,
                      width: 1.5,
                    ),
                    borderRadius: radius,
                  )
                : inputBorder,
            errorBorder: OutlineInputBorder(
              borderSide: BorderSide(color: customTheme.errorColor),
              borderRadius: radius,
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderSide: BorderSide(
                color: customTheme.errorColor,
                width: 1.5,
              ),
              borderRadius: radius,
            ),
            suffixIcon: suffixIcon,
            errorMaxLines: 3,
            counterText: "",
          ),
        ),
      ],
    );
  }
}

// class CustomeTextBoxFloatingLabel extends StatelessWidget {
//   final String? labelText;
//   final String? hintText;
//   final String? initialValue;
//   final Widget? suffixIcon;
//   final EdgeInsetsGeometry? contentPadding;
//   final int maxLines;
//   final int? maxLength;
//   final TextEditingController? controller;
//   final bool enabled;
//   final bool isBorderRequired;
//   final bool realOnly;
//   final TextAlign? textAlign;
//   final String? Function(String?)? validator;
//   final String? Function(String?)? onChanged;
//   final Function()? onTap;
//   final TextInputType keyboardType;
//   final FocusNode? focusNode;
//   final bool? obscureText;
//   final bool? enableOnlyDigits;
//   final bool isFocused;
//   // final bool isRequired;

//   const CustomeTextBoxFloatingLabel({
//     super.key,
//     this.labelText,
//     this.hintText,
//     this.initialValue,
//     this.suffixIcon,
//     this.contentPadding,
//     this.maxLines = 1,
//     this.maxLength,
//     this.controller,
//     this.textAlign,
//     this.enabled = true,
//     this.isBorderRequired = true,
//     this.realOnly = false,
//     // required String? Function(dynamic value) validator,
//     this.validator,
//     this.onChanged,
//     this.onTap,
//     this.keyboardType = TextInputType.text,
//     this.focusNode,
//     this.obscureText = false,
//     this.enableOnlyDigits = false,
//     this.isFocused = false,
//     // this.isRequired = false,
//   });

//   @override
//   Widget build(BuildContext context) {
//     return Wrap(
//       children: [
//         TextFormField(
//           initialValue: initialValue,
//           textAlign: textAlign ?? TextAlign.left,
//           validator: validator,
//           controller: controller,
//           readOnly: realOnly,
//           enabled: enabled,
//           maxLines: obscureText! ? 1 : maxLines,
//           maxLength: maxLength,
//           keyboardType: keyboardType,
//           focusNode: focusNode,
//           onChanged: onChanged,
//           onTap: () {
//             if (onTap != null) {
//               onTap!();
//             }
//           },
//           obscureText: obscureText ?? false,
//           inputFormatters:
//               (enableOnlyDigits ?? false)
//                   ? <TextInputFormatter>[
//                     FilteringTextInputFormatter.allow(RegExp(r'[0-9]')),
//                     FilteringTextInputFormatter.digitsOnly,
//                     LengthLimitingTextInputFormatter(10),
//                   ]
//                   : null,
//           style: TextStyle(
//             color: Color.fromARGB(255, 10, 22, 41),
//           ), //   textRegular
//           decoration: InputDecoration(
//             // label: RichText(
//             //   text: TextSpan(
//             //     text: labelText ?? "", // Base label text
//             //     style: const TextStyle(color: Colors.grey), // Default label text color
//             //     children: [
//             //       if (isRequired) // Conditionally add the red asterisk
//             //         const TextSpan(
//             //           text: '*',
//             //           style: TextStyle(color: Colors.red), // Asterisk in red color
//             //         ),
//             //     ],
//             //   ),
//             // ),
//             labelText: labelText ?? "",
//             floatingLabelBehavior: FloatingLabelBehavior.always,
//             labelStyle: TextStyle(
//               color: Color.fromARGB(255, 125, 133, 146),
//               fontSize: 21, //isFocused ? 22.0 : 16.0,
//             ),
//             hintText: hintText,
//             hintStyle: TextStyle(color: Color.fromARGB(255, 125, 133, 146)),
//             contentPadding:
//                 contentPadding ??
//                 const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
//             fillColor:
//                 enabled
//                     ? Colors.transparent
//                     : const Color.fromARGB(255, 244, 249, 253),
//             filled: true,
//             disabledBorder: OutlineInputBorder(
//               borderSide: BorderSide(
//                 color: Color.fromARGB(255, 216, 224, 240),
//                 width: 1.5,
//               ),
//               borderRadius: BorderRadius.all(Radius.circular(15)),
//             ),
//             enabledBorder:
//                 isBorderRequired
//                     ? OutlineInputBorder(
//                       borderSide: BorderSide(
//                         color: Color.fromARGB(255, 216, 224, 240),
//                         width: 1.5,
//                       ),
//                       borderRadius: BorderRadius.all(Radius.circular(15)),
//                     )
//                     : OutlineInputBorder(
//                       borderSide: BorderSide(
//                         color: Color.fromARGB(0, 216, 224, 240),
//                         width: 0,
//                       ),
//                       borderRadius: BorderRadius.all(Radius.circular(15)),
//                     ),
//             focusedBorder:
//                 isBorderRequired
//                     ? OutlineInputBorder(
//                       borderSide: BorderSide(
//                         color: Color.fromARGB(255, 216, 224, 240),
//                         width: 1.5,
//                       ),
//                       borderRadius: BorderRadius.all(Radius.circular(15)),
//                     )
//                     : OutlineInputBorder(
//                       borderSide: BorderSide(
//                         color: Color.fromARGB(0, 216, 224, 240),
//                         width: 0,
//                       ),
//                       borderRadius: BorderRadius.all(Radius.circular(15)),
//                     ),
//             errorBorder: OutlineInputBorder(
//               borderSide: BorderSide(
//                 color: Color.fromARGB(255, 244, 67, 54),
//                 width: 1.5,
//               ),
//               borderRadius: BorderRadius.all(Radius.circular(15)),
//             ),
//             focusedErrorBorder: OutlineInputBorder(
//               borderSide: BorderSide(
//                 color: Color.fromARGB(255, 244, 67, 54),
//                 width: 1.5,
//               ),
//               borderRadius: BorderRadius.all(Radius.circular(15)),
//             ),
//             suffixIcon: suffixIcon,
//             errorMaxLines: 3,
//             counterText: "",
//           ),
//         ),
//       ],
//     );
//   }
// }
