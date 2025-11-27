// lib/models/category_attribute.dart
class CategoryAttribute {
  final String id;
  final String name;
  final String type;
  final bool isRequired;
  final bool isCustomizable;
  final bool isMultipleSelection;
  final List<AttributeValue> values;
  final String? inputType;

  CategoryAttribute({
    required this.id,
    required this.name,
    required this.type,
    this.isRequired = false,
    this.isCustomizable = false,
    this.isMultipleSelection = false,
    this.values = const [],
    this.inputType,
  });

  factory CategoryAttribute.fromJson(Map<String, dynamic> json) {
    return CategoryAttribute(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      isRequired: json['is_required'] == true, // Backend normalizes TikTok's typo 'is_requried' -> 'is_required'
      isCustomizable: json['is_customizable'] == true,
      isMultipleSelection: json['is_multiple_selection'] == true,
      values: (json['values'] as List<dynamic>?)
              ?.map((v) => AttributeValue.fromJson(v))
              .toList() ??
          [],
      inputType: json['input_type']?.toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type,
      'is_required': isRequired,
      'is_customizable': isCustomizable,
      'is_multiple_selection': isMultipleSelection,
      'values': values.map((v) => v.toJson()).toList(),
      'input_type': inputType,
    };
  }
}

class AttributeValue {
  final String id;
  final String name;
  final bool isCustom;

  AttributeValue({
    required this.id,
    required this.name,
    this.isCustom = false,
  });

  factory AttributeValue.fromJson(Map<String, dynamic> json) {
    return AttributeValue(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      isCustom: json['is_custom'] == true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'is_custom': isCustom,
    };
  }
}

// Selected attribute value for form submission
class SelectedAttribute {
  final String attributeId;
  final List<String> valueIds;
  final String? customValue;

  SelectedAttribute({
    required this.attributeId,
    this.valueIds = const [],
    this.customValue,
  });

  Map<String, dynamic> toJson(CategoryAttribute attribute) {
    final result = <String, dynamic>{
      'id': attributeId,
    };

    // TikTok Shop API format per documentation
    // For customizable attributes, custom values go inside the 'values' array (without id)
    // For regular attributes, values must include both 'id' and 'name'

    if (valueIds.isNotEmpty) {
      // User selected from dropdown - include id and name
      result['values'] = valueIds.map((id) {
        final value = attribute.values.firstWhere(
          (v) => v.id == id,
          orElse: () => AttributeValue(id: id, name: ''),
        );
        return {
          'id': id,
          'name': value.name,
        };
      }).toList();
    } else if (customValue != null && customValue!.isNotEmpty) {
      // User input custom value - only include name (no id)
      result['values'] = [
        {
          'name': customValue,
        }
      ];
    } else {
      // No value selected and no custom value
      result['values'] = [];
    }

    return result;
  }
}
