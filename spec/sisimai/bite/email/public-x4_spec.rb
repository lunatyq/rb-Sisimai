require 'spec_helper'
require './spec/sisimai/bite/email/code'
enginename = 'X4'
isexpected = [
  { 'n' => '01', 's' => /\A5[.]0[.]\d+\z/, 'r' => /mailboxfull/,   'b' => /\A1\z/ },
  { 'n' => '02', 's' => /\A5[.]0[.]\d+\z/, 'r' => /mailboxfull/,   'b' => /\A1\z/ },
  { 'n' => '03', 's' => /\A5[.]1[.]1\z/,   'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '04', 's' => /\A5[.]0[.]\d+\z/, 'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '05', 's' => /\A5[.]0[.]\d+\z/, 'r' => /userunknown/,   'b' => /\A0\z/ },
  { 'n' => '06', 's' => /\A5[.]0[.]\d+\z/, 'r' => /mailboxfull/,   'b' => /\A1\z/ },
  { 'n' => '07', 's' => /\A4[.]4[.]1\z/,   'r' => /networkerror/,  'b' => /\A1\z/ },
]
Sisimai::Bite::Email::Code.maketest(enginename, isexpected)

