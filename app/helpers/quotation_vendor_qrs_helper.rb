module QuotationVendorQrsHelper
  ONES = %w[zero one two three four five six seven eight nine ten eleven twelve thirteen fourteen fifteen sixteen seventeen eighteen nineteen].freeze
  TENS = %w[zero ten twenty thirty forty fifty sixty seventy eighty ninety].freeze

  def amount_in_words(amount)
    amount = amount.to_d
    rupees = amount.floor
    paise = ((amount - rupees) * 100).round

    rupee_words = number_to_words(rupees)
    paise_words = paise.positive? ? " and #{number_to_words(paise)} paise" : ""

    "#{rupee_words} rupees#{paise_words} only".capitalize
  end

  private

  def number_to_words(number)
    number = number.to_i
    return ONES[number] if number < 20
    return "#{TENS[number / 10]} #{ONES[number % 10]}".strip if number < 100
    return "#{ONES[number / 100]} hundred #{number_to_words(number % 100)}".strip if number < 1000 && (number % 100).positive?
    return "#{ONES[number / 100]} hundred" if number < 1000
    return "#{number_to_words(number / 1000)} thousand #{number_to_words(number % 1000)}".strip if number < 100_000 && (number % 1000).positive?
    return "#{number_to_words(number / 1000)} thousand" if number < 100_000
    return "#{number_to_words(number / 100_000)} lakh #{number_to_words(number % 100_000)}".strip if number < 10_000_000 && (number % 100_000).positive?
    return "#{number_to_words(number / 100_000)} lakh" if number < 10_000_000

    "#{number_to_words(number / 10_000_000)} crore #{number_to_words(number % 10_000_000)}".strip
  end
end
