import { injectReducer } from "../../store.js";

/**
 * The FIX. Identical behaviour, but every require() takes its property at the
 * require site, so webpack never needs a whole-namespace reference.
 *
 * NOTE: destructuring does NOT work as a fix --
 *   const { NAME, default: r } = require("...")   // still leaks the placeholder
 */
export default function makeTeacherRoute(store) {
  return {
    path: ":curriculumProgramId",
    load: () =>
      new Promise((resolve, reject) => {
        require.ensure(
          [],
          require => {
            const teacherReducer = require("../../modules/TeacherModule.js").default;
            injectReducer(store, { key: "teacher", reducer: teacherReducer });

            const classRoomReducer = require("../../modules/ClassRoomModule.js").default;
            injectReducer(store, { key: "classRoom", reducer: classRoomReducer });

            injectReducer(store, {
              key: require("../../modules/WorksheetModules.js").NAME,
              reducer: require("../../modules/WorksheetModules.js").default,
            });
            injectReducer(store, {
              key: require("../../modules/AdministratorModule.js").NAME,
              reducer: require("../../modules/AdministratorModule.js").default,
            });
            injectReducer(store, {
              key: require("../../modules/PortfolioReviewModule.js").NAME,
              reducer: require("../../modules/PortfolioReviewModule.js").default,
            });
            injectReducer(store, {
              key: "timetablePlanner",
              reducer: require("../../modules/TimetablePlannerModule.js").default,
            });

            resolve("teacher route loaded");
          },
          err => reject(err),
          "teacher"
        );
      }),
  };
}
