Devise.module_eval {
  mattr_accessor :approval_recepient
  @@approval_recepient = nil
}

DeviseMailer.module_eval {
  def approval_instructions(record)
    setup_mail(record, :approval_instructions)
    recipients    Devise.approval_recepient
  end
}
