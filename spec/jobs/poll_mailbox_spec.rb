require 'rails_helper'
require_dependency 'jobs/regular/process_post'

describe Jobs::PollMailbox do

  let(:poller) { Jobs::PollMailbox.new }

  describe ".execute" do

    it "does no polling if pop3_polling_enabled is false" do
      SiteSetting.expects(:pop3_polling_enabled).returns(false)
      poller.expects(:poll_pop3).never
      poller.execute({})
    end

    it "polls when pop3_polling_enabled is true" do
      SiteSetting.expects(:pop3_polling_enabled).returns(true)
      poller.expects(:poll_pop3).once
      poller.execute({})
    end

  end

  describe ".poll_pop3" do

    it "logs an error on pop authentication error" do
      Net::POP3.any_instance.expects(:start).raises(Net::POPAuthenticationError.new)
      Discourse.expects(:handle_job_exception)
      poller.poll_pop3
    end

    it "calls enable_ssl when the setting is enabled" do
      SiteSetting.pop3_polling_ssl = true
      Net::POP3.any_instance.stubs(:start)
      Net::POP3.any_instance.expects(:enable_ssl)
      poller.poll_pop3
    end

    it "does not call enable_ssl when the setting is disabled" do
      SiteSetting.pop3_polling_ssl = false
      Net::POP3.any_instance.stubs(:start)
      Net::POP3.any_instance.expects(:enable_ssl).never
      poller.poll_pop3
    end
  end

  describe "#process_popmail" do
    def process_popmail(email_name)
      pop_mail = stub("pop mail")
      pop_mail.expects(:pop).returns(email(email_name))
      Jobs::PollMailbox.new.process_popmail(pop_mail)
    end

    it "does not reply to a bounced email" do
      expect { process_popmail(:bounced_email) }.to_not change { ActionMailer::Base.deliveries.count }

      incoming_email = IncomingEmail.last

      expect(incoming_email.rejection_message).to eq(
        I18n.t("email.incoming.errors.bounced_email_report")
      )
    end

    it "does not reply to an email containing a reply to an auto generated email" do
      expect { process_popmail(:bounced_email_2) }.to_not change { ActionMailer::Base.deliveries.count }

      incoming_email = IncomingEmail.last

      expect(incoming_email.rejection_message).to eq(
        I18n.t("email.incoming.errors.auto_generated_email_reply")
      )
    end
  end

end
