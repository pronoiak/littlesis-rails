GoodJob.preserve_job_records = true
GoodJob.retry_on_unhandled_error = false

ActionMailer::MailDeliveryJob.retry_on StandardError, wait: :polynomially_longer, attempts: 100
