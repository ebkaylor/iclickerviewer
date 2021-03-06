class ClassPeriodsController < ApplicationController
  include ApplicationHelper
  # -------------------------------------------------------------
  # GET /class_periods/1
  def show
    start = current_time
    get_questions_course_class_period
    total = current_time - start
    puts "total DB prep time for class_periods#show is #{total}"
    # get_match_stats(ClassPeriod.find_by(id: params[:id]))
  end

  # -------------------------------------------------------------
  # POST /class_periods/1
  def update
    # TODO Can we iterate through questions listed in parameters, not all
    #   questions from DB? One issue is how to know that something has been
    #   unchecked, if that is the only change. The current approach is a
    #   conservative approach.
    Question.where(class_period_id: params[:id]).each do |question|
      matching_question_id = params[:questions][question.id.to_s][:matching_questions]
      if matching_question_id
        match_type = params[:questions][question.id.to_s][:match_type]
        if match_type == 'identical'
          match_type = 0
        elsif match_type == 'modified'
          match_type = 1
        else
          match_type = nil
        end
        mq = MatchingQuestion.find_or_create_by(question_id: question.id,
          matching_question_id: matching_question_id,
          match_type: match_type,
          is_match: 1)
      end

      # Edit matching questions where we set a different match_type
      to_edit = params[:questions][question.id.to_s][:edit_matching_questions]
      if to_edit
        to_edit.each do |edit_matching_question_id, match_type|
          edit_matching_question_id = Integer(edit_matching_question_id)
          match_type = Integer(match_type)

          mq = MatchingQuestion.find_by(question_id: question.id,
            matching_question_id: edit_matching_question_id)
          mq.match_type = match_type
          mq.save
        end
      end

      # Delete any matching questions that are to be deleted.
      to_delete = params[:questions][question.id.to_s][:delete_matching_questions]
      if to_delete
        to_delete.each do |delete_matching_question_id|
          # Delete in both directions, [question_id, matching_question_id]
          #   and also [matching_question_id, question_id]
          MatchingQuestion.find_by(question_id: question.id,
            matching_question_id: delete_matching_question_id).destroy
        end
      end
      # TODO more elegant way to create self-referential many-to-many.
      # Delete the matching_questions key from params, now that we've already
      #   used it. This allows us to use update_attributes without getting
      #   an error for "Unpermitted paramter".
      params[:questions][question.id.to_s].delete(:matching_questions)
      question.update_attributes(question_params(question))
    end
    # Finally, look up the course, class period, and questions we just updated to make
    #   them available to to the view. We are going to re-direct to the show view,
    #   but NOT the show controller.
    get_questions_course_class_period
    get_match_stats(ClassPeriod.find_by(id: params[:id]))

    # Basically, this is a re-direct ONLY for rendering!
    #   It does NOT call the show method in this file.
    render :show
  end

  def update_course_hash
    new_hash = get_course_hash
    new_hash = new_hash.to_json.gsub("\n", '')
    course_hash = CourseHash.find_or_create_by(id:1)
    course_hash.course_hash = new_hash
    course_hash.save
    redirect_to class_period_path params[:id]
  end

  private

  def current_time
    return Time.now.to_f
  end

  # -------------------------------------------------------------
  def get_match_stats(class_period)
    @matches = Hash.new
    class_period.questions.each do |q|
      q.matched_questions.where(:matching_questions => {:is_match => 1}).each do |mq|
        next if q.id == mq.id or q.class_period_id == mq.class_period_id
        increment(@matches, q.id)
      end
    end

    @possible_matches = Hash.new
    class_period.questions.each do |q|
      q.matched_questions.where(:matching_questions => {:is_match => nil}).each do |mq|
        next if q.id == mq.id or q.class_period_id == mq.class_period_id
        increment(@possible_matches, q.id)
      end
    end

    @nonmatches = Hash.new
    class_period.questions.each do |q|
      q.matched_questions.where(:matching_questions => {:is_match => 0}).each do |mq|
        next if q.id == mq.id or q.class_period_id == mq.class_period_id
        increment(@nonmatches, q.id)
      end
    end
  end

  # -------------------------------------------------------------
  def get_course_hash
    course_hash = Hash.new
    Course.all.each do |course|
      class_period_hash = Hash.new
      ClassPeriod.where(course_id: course.id).each do |class_period|
        question_hash = Hash.new
        Question.where(class_period_id: class_period.id).each do |question|
          question_hash[question.question_index] = question.id
        end
        class_period_hash[class_period.session_code] = question_hash
      end
      course_hash[course.folder_name] = class_period_hash
    end
    return course_hash
  end

  # -------------------------------------------------------------
  def question_params(question)
    # FIXME Is setting empty strings to nil even necessary?
    if params[:questions][question.id.to_s][:question_pair] == ""
      params[:questions][question.id.to_s][:question_pair] = nil
    end

    # TODO Document require vs permit, as well as how :questions gets us the array.
    return params.require(:questions).require(question.id.to_s).permit(:correct_a,
      :correct_b, :correct_c, :correct_d, :correct_e, :question_type, :question_pair)
  end

  # -------------------------------------------------------------
  def get_questions_course_class_period
    # puts "course: #{params['old_dynamic_course_selected']}"
    # puts "class: #{params['old_dynamic_class_period_selected']}"
    # puts "question: #{params['old_dynamic_question_selected']}"
    # puts "has key? #{params.has_key?('old_dynamic_course_selected')}"
    @old_dynamic_course_selected = ''
    if params.has_key?('old_dynamic_course_selected')
      @old_dynamic_course_selected = params['old_dynamic_course_selected']
    end
    @old_dynamic_class_period_selected = ''
    if params.has_key?('old_dynamic_class_period_selected')
      @old_dynamic_class_period_selected = params['old_dynamic_class_period_selected']
    end
    old_dynamic_question_selected = ''
    if params.has_key?('old_dynamic_question_selected')
      @old_dynamic_question_selected = params['old_dynamic_question_selected']
    end
    # puts "ivar course: #{@old_dynamic_course_selected}"
    # puts "ivar class: #{@old_dynamic_class_period_selected}"
    # puts "ivar ques: #{@old_dynamic_question_selected}"
    # Look up the class period, course, and questions
    @class_period = ClassPeriod.find_by(id: params[:id])
    # For making a link to the next class.
    # TODO CACHE should we cache this? probably not worth it.
    @next_class_period = ClassPeriod.where("session_code > ? and course_id = ?",
      @class_period.session_code, @class_period.course_id).first
    @course = Course.find_by(id: @class_period.course_id)
    @questions = Question.where(class_period_id: @class_period.id).order(:question_index)
    # Look up a hash from course_name => session_code (class_period) => question_index => question_id

    # TODO cache this!
    start_hash = current_time
    something_else =CourseHash.first
    if something_else!=nil
      @course_hash = CourseHash.first.course_hash
    else
      @course_hash = get_course_hash
    end
    total_hash = current_time - start_hash
    puts "@course_hash time is #{total_hash}"

    # Average time taken per clicker question
    total_time = 0.0
    num_questions = 0.0
    @questions.each do |q|
      total_time += q.num_seconds
      num_questions += 1
    end
    @avg_time = (total_time / num_questions).round(0)

  end
end
